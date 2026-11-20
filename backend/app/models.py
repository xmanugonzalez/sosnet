from datetime import datetime, timezone

from sqlalchemy import Uuid
from sqlalchemy.orm import deferred

from .extensions import db


def utcnow():
    return datetime.now(timezone.utc)


class TipoEmergencia(db.Model):
    __tablename__ = "tipos_emergencia"
    __table_args__ = {"schema": "public"}

    id_tipo = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(100), nullable=False)
    descripcion = db.Column(db.String(255), nullable=True)

    solicitudes = db.relationship("SolicitudSOS", back_populates="tipo")


class Dispositivo(db.Model):
    __tablename__ = "dispositivos"
    __table_args__ = {"schema": "public"}

    id_dispositivo = db.Column(db.Integer, primary_key=True)
    codigo = db.Column(db.String(50), nullable=False, unique=True)
    nombre = db.Column(db.String(100), nullable=False)
    tipo = db.Column(db.String(30), nullable=False)
    estado = db.Column(db.String(20), nullable=False, default="activo")
    fecha_registro = db.Column(
        db.DateTime(timezone=True), nullable=False, default=utcnow
    )

    solicitudes = db.relationship("SolicitudSOS", back_populates="dispositivo")
    registros = db.relationship(
        "RegistroComunicacion", back_populates="dispositivo"
    )


class SolicitudSOS(db.Model):
    __tablename__ = "solicitudes_sos"
    __table_args__ = {"schema": "public"}

    id_solicitud = db.Column(db.Integer, primary_key=True)
    codigo_mensaje = db.Column(db.String(50), nullable=False, unique=True)
    nombre_solicitante = db.Column(db.String(100), nullable=True)
    id_tipo = db.Column(
        db.Integer,
        db.ForeignKey("public.tipos_emergencia.id_tipo"),
        nullable=False,
    )
    id_dispositivo = db.Column(
        db.Integer,
        db.ForeignKey("public.dispositivos.id_dispositivo"),
        nullable=False,
    )
    ubicacion = db.Column(db.String(255), nullable=False)
    cantidad_personas = db.Column(db.Integer, nullable=False, default=1)
    descripcion = db.Column(db.String(500), nullable=True)
    prioridad = db.Column(db.String(20), nullable=False, default="media")
    estado = db.Column(db.String(30), nullable=False, default="pending")
    fecha_recepcion = db.Column(
        db.DateTime(timezone=True), nullable=False, default=utcnow
    )
    actualizado_en = db.Column(
        db.DateTime(timezone=True), nullable=False, default=utcnow
    )

    tipo = db.relationship(
        "TipoEmergencia", back_populates="solicitudes", lazy="joined"
    )
    dispositivo = db.relationship(
        "Dispositivo", back_populates="solicitudes", lazy="joined"
    )
    registros = db.relationship(
        "RegistroComunicacion",
        back_populates="solicitud",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    historial = db.relationship(
        "HistorialEstado",
        back_populates="solicitud",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

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
    __tablename__ = "registros_comunicacion"
    __table_args__ = {"schema": "public"}

    id_registro = db.Column(db.Integer, primary_key=True)
    id_solicitud = db.Column(
        db.Integer,
        db.ForeignKey("public.solicitudes_sos.id_solicitud"),
        nullable=False,
    )
    fecha_recepcion = db.Column(
        db.DateTime(timezone=True), nullable=False, default=utcnow
    )
    estado_recepcion = db.Column(db.String(30), nullable=False, default="recibido")
    id_dispositivo = db.Column(
        db.Integer,
        db.ForeignKey("public.dispositivos.id_dispositivo"),
        nullable=False,
    )

    solicitud = db.relationship("SolicitudSOS", back_populates="registros")
    dispositivo = db.relationship("Dispositivo", back_populates="registros")


class Usuario(db.Model):
    __tablename__ = "usuarios"
    __table_args__ = {"schema": "public"}

    id_usuario = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(100), nullable=False)
    usuario = db.Column(db.String(50), nullable=False)
    correo = db.Column(db.String(120), nullable=True)
    # No se carga por defecto: el rol sosnet_api no tiene SELECT sobre esta
    # columna. El login la obtiene mediante fn_login_usuario (SECURITY DEFINER).
    contrasena = deferred(db.Column(db.String(255), nullable=False))
    rol = db.Column(db.String(30), nullable=False)
    activo = db.Column(db.Boolean, nullable=False, default=True)
    token_version = db.Column(
        db.Integer, nullable=False, default=0, server_default="0"
    )
    ultimo_acceso = db.Column(db.DateTime(timezone=True), nullable=True)
    fecha_registro = db.Column(
        db.DateTime(timezone=True), nullable=False, default=utcnow
    )
    supabase_uid = db.Column(Uuid, nullable=True, unique=True)

    historial = db.relationship("HistorialEstado", back_populates="usuario")
    actividad = db.relationship("Actividad", back_populates="usuario")


class ConfiguracionCentral(db.Model):
    __tablename__ = "configuracion_central"
    __table_args__ = {"schema": "public"}

    id_configuracion = db.Column(db.Integer, primary_key=True, default=1)
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
    __tablename__ = "actividad"
    __table_args__ = {"schema": "auditoria"}

    id_actividad = db.Column(db.Integer, primary_key=True)
    id_usuario = db.Column(
        db.Integer,
        db.ForeignKey("public.usuarios.id_usuario"),
        nullable=True,
    )
    accion = db.Column(db.String(50), nullable=False)
    descripcion = db.Column(db.String(255), nullable=False)
    entidad = db.Column(db.String(40), nullable=True)
    entidad_id = db.Column(db.Integer, nullable=True)
    fecha = db.Column(db.DateTime(timezone=True), nullable=False, default=utcnow)

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
    __tablename__ = "historial_estados"
    __table_args__ = {"schema": "auditoria"}

    id_historial = db.Column(db.Integer, primary_key=True)
    id_solicitud = db.Column(
        db.Integer,
        db.ForeignKey("public.solicitudes_sos.id_solicitud"),
        nullable=False,
    )
    id_usuario = db.Column(
        db.Integer,
        db.ForeignKey("public.usuarios.id_usuario"),
        nullable=False,
    )
    estado_anterior = db.Column(db.String(30), nullable=True)
    estado_nuevo = db.Column(db.String(30), nullable=False)
    fecha_cambio = db.Column(
        db.DateTime(timezone=True), nullable=False, default=utcnow
    )
    observacion = db.Column(db.String(255), nullable=True)

    solicitud = db.relationship("SolicitudSOS", back_populates="historial")
    usuario = db.relationship("Usuario", back_populates="historial")
