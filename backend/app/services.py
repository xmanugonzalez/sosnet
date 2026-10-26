from uuid import uuid4

from .extensions import db
from .models import (
    Dispositivo,
    HistorialEstado,
    RegistroComunicacion,
    SolicitudSOS,
    TipoEmergencia,
    Usuario,
    utcnow,
)

VALID_PRIORITIES = {"alta", "media", "baja"}
VALID_STATUSES = {"pending", "in_progress", "resolved"}


def generar_codigo_mensaje():
    return f"SOS-{utcnow():%Y%m%d%H%M%S}-{uuid4().hex[:6].upper()}"


def obtener_o_crear_tipo(nombre):
    nombre = str(nombre or "").strip()[:100] or "Otra"
    tipo = TipoEmergencia.query.filter_by(nombre=nombre).first()
    if tipo is None:
        tipo = TipoEmergencia(nombre=nombre)
        db.session.add(tipo)
        db.session.flush()
    return tipo


def obtener_o_crear_dispositivo(codigo):
    codigo = str(codigo or "").strip()[:50] or "DESCONOCIDO"
    dispositivo = Dispositivo.query.filter_by(codigo=codigo).first()
    if dispositivo is None:
        dispositivo = Dispositivo(
            codigo=codigo,
            nombre=codigo,
            tipo="desconocido",
            estado="activo",
            fecha_registro=utcnow(),
        )
        db.session.add(dispositivo)
        db.session.flush()
    return dispositivo


def obtener_usuario_sistema():
    usuario = Usuario.query.filter_by(usuario="sistema").first()
    if usuario is None:
        usuario = Usuario(
            nombre="Sistema SOSNET",
            usuario="sistema",
            contrasena="!",
            rol="sistema",
            fecha_registro=utcnow(),
        )
        db.session.add(usuario)
        db.session.flush()
    return usuario


def registrar_historial(solicitud, estado_anterior, estado_nuevo, observacion=None):
    db.session.add(
        HistorialEstado(
            solicitud=solicitud,
            usuario=obtener_usuario_sistema(),
            estado_anterior=estado_anterior,
            estado_nuevo=estado_nuevo,
            fecha_cambio=utcnow(),
            observacion=observacion,
        )
    )


def registrar_solicitud(payload):
    tipo = obtener_o_crear_tipo(payload.get("emergency_type") or payload.get("type"))
    dispositivo = obtener_o_crear_dispositivo(payload.get("device_id"))
    ahora = utcnow()

    solicitud = SolicitudSOS(
        codigo_mensaje=generar_codigo_mensaje(),
        nombre_solicitante=(
            str(payload.get("reporter_name") or payload.get("name") or "").strip()[:100] or None
        ),
        tipo=tipo,
        dispositivo=dispositivo,
        ubicacion=_construir_ubicacion(payload),
        cantidad_personas=_normalizar_personas(payload.get("people")),
        descripcion=(
            str(payload.get("message") or "").strip()[:500] or "Solicitud de emergencia"
        ),
        prioridad=_normalizar_prioridad(payload.get("priority")),
        estado="pending",
        fecha_recepcion=ahora,
    )
    db.session.add(solicitud)
    db.session.flush()

    db.session.add(
        RegistroComunicacion(
            solicitud=solicitud,
            dispositivo=dispositivo,
            fecha_recepcion=ahora,
            estado_recepcion="recibido",
        )
    )
    db.session.commit()
    return solicitud


def _normalizar_personas(value):
    try:
        people = int(value)
    except (TypeError, ValueError):
        people = 1
    return max(1, min(people, 1000))


def _normalizar_prioridad(value):
    priority = str(value or "media").strip().lower()
    return priority if priority in VALID_PRIORITIES else "media"


def _construir_ubicacion(payload):
    ubicacion = str(payload.get("location") or "").strip()
    coordinates = _coordinates(payload.get("latitude"), payload.get("longitude"))

    if not ubicacion:
        ubicacion = "Ubicación GPS" if coordinates else "No indicada"

    if coordinates:
        latitud, longitud = coordinates
        sufijo = f" (GPS: {latitud:.6f}, {longitud:.6f})"
        if sufijo not in ubicacion:
            ubicacion = f"{ubicacion}{sufijo}"

    return ubicacion[:255]


def _coordinates(latitude, longitude):
    if latitude in (None, "") or longitude in (None, ""):
        return None
    try:
        latitud = float(latitude)
        longitud = float(longitude)
    except (TypeError, ValueError):
        return None
    if latitud == 0 and longitud == 0:
        return None
    return latitud, longitud
