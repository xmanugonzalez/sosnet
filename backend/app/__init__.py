from datetime import datetime, timedelta, timezone

import click
from flask import Flask, jsonify, request
from flask_cors import CORS

from .admin import admin
from .auth import auth
from .config import Config
from .extensions import db, jwt, limiter
from .models import HistorialEstado, RegistroComunicacion, SolicitudSOS
from .routes import api
from .serial_reader import start_serial_reader

INSECURE_SECRETS = {
    "",
    "dev-only-secret",
    "cambiar-en-produccion",
    "dev-only-jwt-secret-change-me-1234567890",
}

jwt_callbacks_registered = False


def _register_jwt_callbacks():
    global jwt_callbacks_registered
    if jwt_callbacks_registered:
        return

    @jwt.unauthorized_loader
    def missing_token(_reason):
        return jsonify({"error": "Token de acceso requerido"}), 401

    @jwt.invalid_token_loader
    def invalid_token(_reason):
        return jsonify({"error": "Token de acceso inválido"}), 401

    @jwt.expired_token_loader
    def expired_token(_header, _payload):
        return jsonify({"error": "La sesión expiró; vuelve a iniciar sesión"}), 401

    @jwt.revoked_token_loader
    def revoked_token(_header, _payload):
        return jsonify({"error": "Token de acceso revocado"}), 401

    jwt_callbacks_registered = True


def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    insecure_config = (
        not app.config["DEBUG"]
        and not app.config["TESTING"]
        and (
            app.config["SECRET_KEY"] in INSECURE_SECRETS
            or app.config["JWT_SECRET_KEY"] in INSECURE_SECRETS
            or app.config["JWT_SECRET_KEY"] == app.config["SECRET_KEY"]
        )
    )
    if insecure_config:
        app.logger.warning(
            "SECRET_KEY/JWT_SECRET_KEY inseguras o iguales: la API quedará "
            "bloqueada hasta configurar valores propios y distintos."
        )

    db.init_app(app)
    jwt.init_app(app)
    limiter.init_app(app)
    _register_jwt_callbacks()

    CORS(
        app,
        resources={
            r"/api/*": {
                "origins": app.config["CORS_ORIGINS"],
                "allow_headers": ["Content-Type", "Authorization"],
                "methods": ["GET", "POST", "PATCH", "PUT", "OPTIONS"],
            }
        },
    )

    app.register_blueprint(api, url_prefix="/api")
    app.register_blueprint(auth, url_prefix="/api/auth")
    app.register_blueprint(admin, url_prefix="/api")

    @app.before_request
    def block_insecure_api():
        if insecure_config and request.path.startswith("/api/"):
            return (
                jsonify(
                    {
                        "code": "insecure_config",
                        "error": (
                            "Configuración insegura: define SECRET_KEY y "
                            "JWT_SECRET_KEY con valores propios y distintos."
                        )
                    }
                ),
                503,
            )
        return None

    @app.after_request
    def add_security_headers(response):
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault("Referrer-Policy", "no-referrer")
        response.headers.setdefault(
            "Permissions-Policy", "geolocation=(self), camera=(), microphone=()"
        )
        if request.path.startswith("/api/"):
            response.headers["Cache-Control"] = "no-store"
        return response

    @app.errorhandler(429)
    def rate_limit_exceeded(_error):
        return jsonify({"error": "Demasiadas solicitudes; intenta de nuevo más tarde"}), 429

    @app.cli.command("purge-old-sos")
    @click.option("--days", type=int, default=None, help="Días de retención.")
    @click.option("--dry-run", is_flag=True, help="Solo muestra cuántas se borrarían.")
    def purge_old_sos(days, dry_run):
        retention_days = (
            days if days is not None else app.config["SOS_RETENTION_DAYS"]
        )
        if retention_days < 1:
            raise click.BadParameter("Los días de retención deben ser mayores que cero.")
        cutoff = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(
            days=retention_days
        )
        query = SolicitudSOS.query.filter(SolicitudSOS.fecha_recepcion < cutoff)
        total = query.count()
        if total == 0:
            click.echo(f"No hay solicitudes anteriores a {retention_days} días.")
            return
        if dry_run:
            click.echo(
                f"Se eliminarían {total} solicitudes anteriores a {retention_days} días."
            )
            return

        ids = [row.id_solicitud for row in query.with_entities(SolicitudSOS.id_solicitud)]
        RegistroComunicacion.query.filter(
            RegistroComunicacion.id_solicitud.in_(ids)
        ).delete(synchronize_session=False)
        HistorialEstado.query.filter(
            HistorialEstado.id_solicitud.in_(ids)
        ).delete(synchronize_session=False)
        SolicitudSOS.query.filter(SolicitudSOS.id_solicitud.in_(ids)).delete(
            synchronize_session=False
        )
        db.session.commit()
        click.echo(
            f"Se eliminaron {total} solicitudes y sus registros asociados "
            f"(retención de {retention_days} días)."
        )

    with app.app_context():
        db.create_all()

    if app.config["SERIAL_ENABLED"]:
        start_serial_reader(app)

    return app
