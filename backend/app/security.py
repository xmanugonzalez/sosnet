from datetime import timezone
from functools import wraps

from flask import g, jsonify
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request

from .extensions import db
from .models import Usuario


def _load_current_user():
    identity = get_jwt_identity()
    try:
        user_id = int(identity)
    except (TypeError, ValueError):
        return None

    user = db.session.get(Usuario, user_id)
    if user is not None and user.activo:
        return user
    return None


def serialize_user(user):
    ultimo_acceso = user.ultimo_acceso
    if ultimo_acceso is not None and ultimo_acceso.tzinfo is None:
        ultimo_acceso = ultimo_acceso.replace(tzinfo=timezone.utc)

    return {
        "id": user.id_usuario,
        "name": user.nombre,
        "username": user.usuario,
        "email": user.correo,
        "role": user.rol,
        "active": bool(user.activo),
        "last_login": ultimo_acceso.isoformat() if ultimo_acceso else None,
    }


def _authorized(admin_only=False):
    verify_jwt_in_request()
    user = _load_current_user()
    if user is None:
        return None, (jsonify({"error": "Sesión no válida o usuario inactivo"}), 401)
    if admin_only and user.rol != "admin":
        return None, (jsonify({"error": "Se requiere rol de administrador"}), 403)
    g.current_user = user
    return user, None


def auth_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        _user, error = _authorized()
        if error:
            return error
        return view(*args, **kwargs)

    return wrapped


def admin_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        _user, error = _authorized(admin_only=True)
        if error:
            return error
        return view(*args, **kwargs)

    return wrapped


def get_current_user():
    return g.current_user
