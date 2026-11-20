from flask import Blueprint, jsonify, request
from flask_jwt_extended import create_access_token
from sqlalchemy import text
from werkzeug.security import check_password_hash

from .db_context import set_db_identity
from .extensions import db, limiter
from .models import Usuario
from .security import auth_required, get_current_user, serialize_user
from .services import cerrar_sesion

auth = Blueprint("auth", __name__)


def _login_row(identifier):
    normalized = str(identifier or "").strip()
    if not normalized:
        return None
    return (
        db.session.execute(
            text("SELECT * FROM public.fn_login_usuario(:identifier)"),
            {"identifier": normalized},
        )
        .mappings()
        .first()
    )


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

    row = _login_row(identifier)
    valid_password = False
    if row is not None:
        try:
            valid_password = check_password_hash(row["contrasena"], str(password))
        except (TypeError, ValueError):
            valid_password = False

    if row is None or not row["activo"] or not valid_password:
        return jsonify({"error": "Credenciales inválidas o cuenta inactiva"}), 401

    expected_role = str(payload.get("role") or "").strip().lower()
    if expected_role == "operator":
        expected_role = "operador"
    if expected_role and expected_role != row["rol"]:
        return jsonify({"error": "La cuenta no corresponde al tipo de acceso elegido"}), 403

    # A partir de aquí la API puede leer la fila propia bajo RLS.
    set_db_identity(row["id_usuario"], row["rol"])
    user = db.session.get(Usuario, row["id_usuario"])
    if user is None:
        return jsonify({"error": "Credenciales inválidas o cuenta inactiva"}), 401

    try:
        db.session.execute(
            text("CALL public.sp_login_exitoso(:usuario)"),
            {"usuario": user.id_usuario},
        )
        db.session.commit()
        db.session.refresh(user)
    except Exception:
        db.session.rollback()
        raise

    token = create_access_token(
        identity=str(user.id_usuario),
        additional_claims={
            "role": user.rol,
            "name": user.nombre,
            "token_version": user.token_version,
        },
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
    cerrar_sesion(user)
    db.session.commit()
    return "", 204
