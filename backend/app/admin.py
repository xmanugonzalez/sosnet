import re

from flask import Blueprint, jsonify, request
from sqlalchemy import func
from werkzeug.security import generate_password_hash

from .extensions import db
from .models import Actividad, ConfiguracionCentral, Usuario, utcnow
from .security import (
    admin_required,
    auth_required,
    get_current_user,
    serialize_user,
)
from .services import registrar_actividad

admin = Blueprint("admin", __name__)

EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
VALID_ROLES = {"operador", "admin"}
MIN_PASSWORD_LENGTH = 8


def _payload():
    payload = request.get_json(silent=True)
    return payload if isinstance(payload, dict) else None


def _normalize_email(value):
    return str(value or "").strip().lower()


def _valid_email(email):
    return bool(EMAIL_PATTERN.match(email)) and len(email) <= 120


def _email_taken(email, exclude_id=None):
    query = Usuario.query.filter(func.lower(Usuario.correo) == email.lower())
    if exclude_id is not None:
        query = query.filter(Usuario.id_usuario != exclude_id)
    return query.first() is not None


def _username_for(email):
    base = re.sub(r"[^a-z0-9._-]+", "", email.split("@")[0].lower()).strip("._-")
    base = (base or "usuario")[:40]
    candidate = base
    suffix = 1
    while Usuario.query.filter(func.lower(Usuario.usuario) == candidate).first():
        suffix += 1
        tail = str(suffix)
        candidate = f"{base[: 40 - len(tail)]}{tail}"
    return candidate


def _get_settings():
    settings = db.session.get(ConfiguracionCentral, 1)
    if settings is None:
        settings = ConfiguracionCentral(
            id_configuracion=1,
            nombre="Central de rescate",
            ubicacion="Asunción, Paraguay",
            actualizado_en=utcnow(),
        )
        db.session.add(settings)
        db.session.flush()
    return settings


@admin.get("/users")
@admin_required
def list_users():
    users = (
        Usuario.query.filter(Usuario.rol != "sistema")
        .order_by(Usuario.nombre.asc())
        .all()
    )
    return jsonify([serialize_user(user) for user in users])


@admin.post("/users")
@admin_required
def create_user():
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Se esperaba un JSON válido"}), 400

    name = str(payload.get("nombre") or payload.get("name") or "").strip()
    email = _normalize_email(payload.get("correo") or payload.get("email"))
    password = str(payload.get("password") or "")
    role = str(payload.get("rol") or payload.get("role") or "operador").strip().lower()

    if not name or len(name) > 100:
        return jsonify({"error": "El nombre es obligatorio (máximo 100 caracteres)"}), 400
    if not _valid_email(email):
        return jsonify({"error": "El correo electrónico no es válido"}), 400
    if _email_taken(email):
        return jsonify({"error": "Ya existe una cuenta con ese correo"}), 409
    if len(password) < MIN_PASSWORD_LENGTH:
        return jsonify({"error": "La contraseña debe tener al menos 8 caracteres"}), 400
    if role not in VALID_ROLES:
        return jsonify({"error": "El rol debe ser operador o admin"}), 400

    user = Usuario(
        nombre=name,
        usuario=_username_for(email),
        correo=email,
        contrasena=generate_password_hash(password),
        rol=role,
        activo=True,
        fecha_registro=utcnow(),
    )
    db.session.add(user)
    db.session.flush()
    registrar_actividad(
        get_current_user(),
        "user_create",
        f"Se creó la cuenta de {user.nombre} ({role})",
        "usuario",
        user.id_usuario,
    )
    db.session.commit()
    return jsonify(serialize_user(user)), 201


@admin.patch("/users/<int:user_id>")
@admin_required
def update_user(user_id):
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Se esperaba un JSON válido"}), 400

    user = db.session.get(Usuario, user_id)
    if user is None:
        return jsonify({"error": "Usuario no encontrado"}), 404
    if user.rol == "sistema":
        return jsonify({"error": "La cuenta del sistema no se puede modificar"}), 400

    current = get_current_user()
    changed = []

    if "nombre" in payload or "name" in payload:
        name = str(payload.get("nombre") or payload.get("name") or "").strip()
        if not name or len(name) > 100:
            return jsonify({"error": "El nombre es obligatorio (máximo 100 caracteres)"}), 400
        if name != user.nombre:
            user.nombre = name
            changed.append("nombre")

    if "correo" in payload or "email" in payload:
        email = _normalize_email(payload.get("correo") or payload.get("email"))
        if not _valid_email(email):
            return jsonify({"error": "El correo electrónico no es válido"}), 400
        if _email_taken(email, exclude_id=user.id_usuario):
            return jsonify({"error": "Ya existe una cuenta con ese correo"}), 409
        if email != user.correo:
            user.correo = email
            changed.append("correo")

    if "rol" in payload or "role" in payload:
        role = str(payload.get("rol") or payload.get("role") or "").strip().lower()
        if role not in VALID_ROLES:
            return jsonify({"error": "El rol debe ser operador o admin"}), 400
        if user.id_usuario == current.id_usuario and role != "admin":
            return jsonify({"error": "No puedes quitarte el rol de administrador"}), 400
        if role != user.rol:
            user.rol = role
            changed.append("rol")

    if "activo" in payload or "active" in payload:
        active = payload.get("activo", payload.get("active"))
        if not isinstance(active, bool):
            return jsonify({"error": "El estado activo debe ser verdadero o falso"}), 400
        if user.id_usuario == current.id_usuario and not active:
            return jsonify({"error": "No puedes desactivar tu propia cuenta"}), 400
        if active != bool(user.activo):
            user.activo = active
            changed.append("estado")

    if "password" in payload:
        password = str(payload.get("password") or "")
        if len(password) < MIN_PASSWORD_LENGTH:
            return jsonify({"error": "La contraseña debe tener al menos 8 caracteres"}), 400
        user.contrasena = generate_password_hash(password)
        changed.append("contraseña")

    if changed:
        registrar_actividad(
            current,
            "user_update",
            f"Se actualizó la cuenta de {user.nombre}: {', '.join(changed)}",
            "usuario",
            user.id_usuario,
        )
        db.session.commit()

    return jsonify(serialize_user(user))


@admin.get("/settings")
@auth_required
def get_settings():
    settings = _get_settings()
    db.session.commit()
    return jsonify(settings.to_dict())


@admin.put("/settings")
@admin_required
def update_settings():
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Se esperaba un JSON válido"}), 400

    name = str(payload.get("name") or payload.get("nombre") or "").strip()
    location = str(payload.get("location") or payload.get("ubicacion") or "").strip()
    if not name or len(name) > 100:
        return jsonify({"error": "El nombre de la central es obligatorio"}), 400
    if not location or len(location) > 150:
        return jsonify({"error": "La ubicación de la central es obligatoria"}), 400

    settings = _get_settings()
    settings.nombre = name
    settings.ubicacion = location
    settings.actualizado_en = utcnow()
    registrar_actividad(
        get_current_user(),
        "settings_update",
        "Se actualizó la identificación de la central",
        "configuracion",
        settings.id_configuracion,
    )
    db.session.commit()
    return jsonify(settings.to_dict())


@admin.get("/activity")
@admin_required
def list_activity():
    events = (
        Actividad.query.order_by(Actividad.fecha.desc()).limit(100).all()
    )
    return jsonify([event.to_dict() for event in events])
