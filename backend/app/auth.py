from flask import Blueprint, jsonify, request
from flask_jwt_extended import create_access_token
from sqlalchemy import func, or_
from werkzeug.security import check_password_hash

from .extensions import db, limiter
from .models import Usuario, utcnow
from .security import auth_required, get_current_user, serialize_user
from .services import registrar_actividad

auth = Blueprint("auth", __name__)


def _find_user(identifier):
    normalized = str(identifier or "").strip().lower()
    if not normalized:
        return None
    return Usuario.query.filter(
        or_(
            func.lower(Usuario.correo) == normalized,
            func.lower(Usuario.usuario) == normalized,
        )
    ).first()


@auth.post("/login")
@limiter.limit("10 per minute")
def login():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"error": "Se esperaba un JSON válido"}), 400

    identifier = payload.get("identifier") or payload.get("email") or payload.get("usuario")
    password = payload.get("password")
    if not identifier or not password:
        return jsonify({"error": "Indica tu correo y contraseña"}), 400

    user = _find_user(identifier)
    valid_password = False
    if user is not None:
        try:
            valid_password = check_password_hash(user.contrasena, str(password))
        except (TypeError, ValueError):
            valid_password = False

    if user is None or not user.activo or not valid_password:
        return jsonify({"error": "Credenciales inválidas o cuenta inactiva"}), 401

    expected_role = str(payload.get("role") or "").strip().lower()
    if expected_role == "operator":
        expected_role = "operador"
    if expected_role and expected_role != user.rol:
        return jsonify({"error": "La cuenta no corresponde al tipo de acceso elegido"}), 403

    user.ultimo_acceso = utcnow()
    registrar_actividad(user, "login", "Inicio de sesión en la central")
    db.session.commit()

    token = create_access_token(
        identity=str(user.id_usuario),
        additional_claims={"role": user.rol, "name": user.nombre},
    )
    return jsonify({"token": token, "user": serialize_user(user)})


@auth.get("/me")
@auth_required
def me():
    return jsonify({"user": serialize_user(get_current_user())})


@auth.post("/logout")
@auth_required
def logout():
    user = get_current_user()
    registrar_actividad(user, "logout", "Cierre de sesión en la central")
    db.session.commit()
    return "", 204
