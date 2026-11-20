from uuid import uuid4

from sqlalchemy import text

from .extensions import db
from .models import utcnow

VALID_PRIORITIES = {"alta", "media", "baja"}
VALID_STATUSES = {"pending", "in_progress", "resolved"}


def generar_codigo_mensaje():
    return f"SOS-{utcnow():%Y%m%d%H%M%S}-{uuid4().hex[:6].upper()}"


def registrar_solicitud(payload):
    """Registra una solicitud mediante el procedimiento transaccional de PostgreSQL.

    El procedimiento crea (si hace falta) el tipo y el dispositivo, inserta la
    solicitud y su registro de comunicación en una sola transacción.
    """
    tipo = str(payload.get("emergency_type") or payload.get("type") or "").strip()[:100]
    tipo = tipo or "Otra"
    dispositivo = str(payload.get("device_id") or "WEB").strip()[:50] or "WEB"
    nombre = (
        str(payload.get("reporter_name") or payload.get("name") or "").strip()[:100]
        or None
    )
    ubicacion = _construir_ubicacion(payload)
    personas = _normalizar_personas(payload.get("people"))
    descripcion = (
        str(payload.get("message") or "").strip()[:500]
        or "Solicitud de emergencia"
    )
    prioridad = _normalizar_prioridad(payload.get("priority"))
    fecha = utcnow()
    codigo = generar_codigo_mensaje()

    try:
        result = db.session.execute(
            text(
                """
                CALL public.sp_registrar_solicitud(
                    :codigo,
                    :nombre,
                    :tipo,
                    :dispositivo,
                    :ubicacion,
                    :personas,
                    :descripcion,
                    :prioridad,
                    :fecha,
                    NULL
                )
                """
            ),
            {
                "codigo": codigo,
                "nombre": nombre,
                "tipo": tipo,
                "dispositivo": dispositivo,
                "ubicacion": ubicacion,
                "personas": personas,
                "descripcion": descripcion,
                "prioridad": prioridad,
                "fecha": fecha,
            },
        )
        row = result.fetchone()
        id_solicitud = row[0] if row else None
        if id_solicitud is None:
            raise RuntimeError("El procedimiento no devolvió el ID de la solicitud")
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise

    return {
        "id": id_solicitud,
        "codigo_mensaje": codigo,
        "device_id": dispositivo,
        "emergency_type": tipo,
        "message": descripcion,
        "reporter_name": nombre,
        "location": ubicacion,
        "people": personas,
        "priority": prioridad,
        "latitude": None,
        "longitude": None,
        "status": "pending",
        "received_at": fecha.isoformat(),
    }


def actualizar_estado(solicitud_id, nuevo_estado, usuario, observacion=None):
    """Delegación al procedimiento; el trigger registra historial y auditoría."""
    db.session.execute(
        text(
            """
            CALL public.sp_actualizar_estado(
                :solicitud_id, :estado, :usuario, :observacion
            )
            """
        ),
        {
            "solicitud_id": solicitud_id,
            "estado": nuevo_estado,
            "usuario": usuario.id_usuario,
            "observacion": observacion,
        },
    )


def registrar_actividad(usuario, accion, descripcion, entidad=None, entidad_id=None):
    db.session.execute(
        text(
            """
            CALL public.sp_registrar_actividad(
                :usuario, :accion, :descripcion, :entidad, :entidad_id
            )
            """
        ),
        {
            "usuario": usuario.id_usuario if usuario else None,
            "accion": str(accion)[:50],
            "descripcion": str(descripcion)[:255],
            "entidad": str(entidad)[:40] if entidad else None,
            "entidad_id": entidad_id,
        },
    )


def cerrar_sesion(usuario):
    db.session.execute(
        text("CALL public.sp_logout_usuario(:usuario)"),
        {"usuario": usuario.id_usuario},
    )


def purgar_solicitudes(dias, dry_run=False):
    result = db.session.execute(
        text("CALL public.sp_purgar_solicitudes_antiguas(:dias, :dry_run, NULL)"),
        {"dias": dias, "dry_run": dry_run},
    )
    row = result.fetchone()
    db.session.commit()
    return row[0] if row else 0


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
