from datetime import datetime, timezone

from .extensions import db


def utcnow():
    return datetime.now(timezone.utc)


class TipoEmergencia(db.Model):
    __tablename__ = "TiposEmergencia"

    id_tipo = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(100), nullable=False)
    descripcion = db.Column(db.String(255), nullable=True)

    solicitudes = db.relationship("SolicitudSOS", back_populates="tipo")


class Dispositivo(db.Model):
    __tablename__ = "Dispositivos"

    id_dispositivo = db.Column(db.Integer, primary_key=True)
    codigo = db.Column(db.String(50), nullable=False, unique=True)
    nombre = db.Column(db.String(100), nullable=False)
    tipo = db.Column(db.String(30), nullable=False)
    estado = db.Column(db.String(20), nullable=False, default="activo")
    fecha_registro = db.Column(db.DateTime(timezone=True), nullable=False, default=utcnow)

    solicitudes = db.relationship("SolicitudSOS", back_populates="dispositivo")
    registros = db.relationship("RegistroComunicacion", back_populates="dispositivo")


class SolicitudSOS(db.Model):
    __tablename__ = "SolicitudesSOS"

    id_solicitud = db.Column(db.Integer, primary_key=True)
    codigo_mensaje = db.Column(db.String(50), nullable=False, unique=True)
    nombre_solicitante = db.Column(db.String(100), nullable=True)
    id_tipo = db.Column(db.Integer, db.ForeignKey("TiposEmergencia.id_tipo"), nullable=False)
    id_dispositivo = db.Column(
        db.Integer, db.ForeignKey("Dispositivos.id_dispositivo"), nullable=False
    )
    ubicacion = db.Column(db.String(255), nullable=False)
    cantidad_personas = db.Column(db.Integer, nullable=False, default=1)
    descripcion = db.Column(db.String(500), nullable=True)
    prioridad = db.Column(db.String(20), nullable=False, default="media")
    estado = db.Column(db.String(30), nullable=False, default="pending", index=True)
    fecha_recepcion = db.Column(db.DateTime(timezone=True), nullable=False, default=utcnow)

    tipo = db.relationship("TipoEmergencia", back_populates="solicitudes", lazy="joined")
    dispositivo = db.relationship("Dispositivo", back_populates="solicitudes", lazy="joined")
    registros = db.relationship("RegistroComunicacion", back_populates="solicitud")
    historial = db.relationship("HistorialEstado", back_populates="solicitud")

    def to_dict(self):
        fecha = self.fecha_recepcion
        if fecha.tzinfo is None:
            fecha = fecha.replace(tzinfo=timezone.utc)

        return {
            "id": self.id_solicitud,
            "codigo_mensaje": self.codigo_mensaje,
            "device_id": self.dispositivo.codigo if self.dispositivo else "desconocido",
            "emergency_type": self.tipo.nombre if self.tipo else "Otra",
            "message": self.descripcion or "",
            "reporter_name": self.nombre_solicitante,
            "location": self.ubicacion,
            "people": self.cantidad_personas,
            "priority": self.prioridad,
            "latitude": None,
            "longitude": None,
            "status": self.estado,
            "received_at": fecha.isoformat(),
        }


class RegistroComunicacion(db.Model):
    __tablename__ = "RegistrosComunicacion"

    id_registro = db.Column(db.Integer, primary_key=True)
    id_solicitud = db.Column(
        db.Integer, db.ForeignKey("SolicitudesSOS.id_solicitud"), nullable=False
    )
    fecha_recepcion = db.Column(db.DateTime(timezone=True), nullable=False, default=utcnow)
    estado_recepcion = db.Column(db.String(30), nullable=False, default="recibido")
    id_dispositivo = db.Column(
        db.Integer, db.ForeignKey("Dispositivos.id_dispositivo"), nullable=False
    )

    solicitud = db.relationship("SolicitudSOS", back_populates="registros")
    dispositivo = db.relationship("Dispositivo", back_populates="registros")


class Usuario(db.Model):
    __tablename__ = "Usuarios"

    id_usuario = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(100), nullable=False)
    usuario = db.Column(db.String(50), nullable=False, unique=True)
    correo = db.Column(db.String(120), nullable=True, unique=True)
    contrasena = db.Column(db.String(255), nullable=False)
    rol = db.Column(db.String(30), nullable=False)
    activo = db.Column(db.Boolean, nullable=False, default=True)
    ultimo_acceso = db.Column(db.DateTime(timezone=True), nullable=True)
    fecha_registro = db.Column(db.DateTime(timezone=True), nullable=False, default=utcnow)

    historial = db.relationship("HistorialEstado", back_populates="usuario")
    actividad = db.relationship("Actividad", back_populates="usuario")


class ConfiguracionCentral(db.Model):
    __tablename__ = "ConfiguracionCentral"

    id_configuracion = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(100), nullable=False)
    ubicacion = db.Column(db.String(150), nullable=False)
    actualizado_en = db.Column(
        db.DateTime(timezone=True), nullable=False, default=utcnow
    )

    def to_dict(self):
        actualizado = self.actualizado_en
        if actualizado is not None and actualizado.tzinfo is None:
            actualizado = actualizado.replace(tzinfo=timezone.utc)
        return {
            "name": self.nombre,
            "location": self.ubicacion,
            "updated_at": actualizado.isoformat() if actualizado else None,
        }


class Actividad(db.Model):
    __tablename__ = "Actividad"

    id_actividad = db.Column(db.Integer, primary_key=True)
    id_usuario = db.Column(
        db.Integer, db.ForeignKey("Usuarios.id_usuario"), nullable=True
    )
    accion = db.Column(db.String(50), nullable=False)
    descripcion = db.Column(db.String(255), nullable=False)
    entidad = db.Column(db.String(40), nullable=True)
    entidad_id = db.Column(db.Integer, nullable=True)
    fecha = db.Column(
        db.DateTime(timezone=True), nullable=False, default=utcnow, index=True
    )

    usuario = db.relationship("Usuario", back_populates="actividad")

    def to_dict(self):
        fecha = self.fecha
        if fecha is not None and fecha.tzinfo is None:
            fecha = fecha.replace(tzinfo=timezone.utc)
        return {
            "id": self.id_actividad,
            "action": self.accion,
            "description": self.descripcion,
            "entity": self.entidad,
            "entity_id": self.entidad_id,
            "actor": self.usuario.nombre if self.usuario else "Sistema",
            "actor_role": self.usuario.rol if self.usuario else "sistema",
            "created_at": fecha.isoformat() if fecha else None,
        }


class HistorialEstado(db.Model):
    __tablename__ = "HistorialEstados"

    id_historial = db.Column(db.Integer, primary_key=True)
    id_solicitud = db.Column(
        db.Integer, db.ForeignKey("SolicitudesSOS.id_solicitud"), nullable=False
    )
    id_usuario = db.Column(db.Integer, db.ForeignKey("Usuarios.id_usuario"), nullable=False)
    estado_anterior = db.Column(db.String(30), nullable=True)
    estado_nuevo = db.Column(db.String(30), nullable=False)
    fecha_cambio = db.Column(db.DateTime(timezone=True), nullable=False, default=utcnow)
    observacion = db.Column(db.String(255), nullable=True)

    solicitud = db.relationship("SolicitudSOS", back_populates="historial")
    usuario = db.relationship("Usuario", back_populates="historial")
