from datetime import timedelta

import pytest
from werkzeug.security import generate_password_hash

from app import create_app
from app.extensions import db
from app.models import ConfiguracionCentral, Usuario, utcnow


class TestConfig:
    TESTING = True
    DEBUG = False
    SECRET_KEY = "test-secret-key-with-enough-length-32"
    JWT_SECRET_KEY = "test-jwt-secret-key-with-enough-length-32"
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=1)
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    CORS_ORIGINS = ["http://localhost:1010"]
    SERIAL_ENABLED = False
    RATELIMIT_ENABLED = False
    SOS_RETENTION_DAYS = 90


def _user(name, username, email, role, password, active=True):
    return Usuario(
        nombre=name,
        usuario=username,
        correo=email,
        contrasena=generate_password_hash(password, method="pbkdf2:sha256:1000"),
        rol=role,
        activo=active,
        fecha_registro=utcnow(),
    )


@pytest.fixture
def app():
    application = create_app(TestConfig)
    with application.app_context():
        db.create_all()
        db.session.add_all(
            [
                _user(
                    "Operador SOSNET",
                    "operador",
                    "operador@sosnet.local",
                    "operador",
                    "OperadorDemo123",
                ),
                _user(
                    "Administrador SOSNET",
                    "admin",
                    "admin@sosnet.local",
                    "admin",
                    "AdminDemo123",
                ),
                _user(
                    "Cuenta inactiva",
                    "inactivo",
                    "inactivo@sosnet.local",
                    "operador",
                    "InactivoDemo123",
                    active=False,
                ),
                Usuario(
                    nombre="Sistema SOSNET",
                    usuario="sistema",
                    correo=None,
                    contrasena="!",
                    rol="sistema",
                    activo=False,
                    fecha_registro=utcnow(),
                ),
                ConfiguracionCentral(
                    id_configuracion=1,
                    nombre="Central de rescate",
                    ubicacion="Asunción, Paraguay",
                    actualizado_en=utcnow(),
                ),
            ]
        )
        db.session.commit()
        yield application
        db.session.remove()
        db.drop_all()


@pytest.fixture
def client(app):
    return app.test_client()


def login(client, identifier, password, role=None):
    payload = {"identifier": identifier, "password": password}
    if role:
        payload["role"] = role
    return client.post("/api/auth/login", json=payload)


@pytest.fixture
def auth_headers(client):
    response = login(client, "operador@sosnet.local", "OperadorDemo123", "operador")
    token = response.get_json()["token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def admin_headers(client):
    response = login(client, "admin@sosnet.local", "AdminDemo123", "admin")
    token = response.get_json()["token"]
    return {"Authorization": f"Bearer {token}"}
