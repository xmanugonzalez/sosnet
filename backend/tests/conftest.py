import os
from datetime import timedelta

import pytest
from sqlalchemy import create_engine, text
from werkzeug.security import generate_password_hash

from app import create_app
from app.extensions import db

TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+psycopg://sosnet_api:sosnet_api_dev@127.0.0.1:55432/sosnet_test",
)
TEST_ADMIN_DATABASE_URL = os.getenv(
    "TEST_ADMIN_DATABASE_URL",
    "postgresql+psycopg://sosnet_admin:sosnet_admin_dev@127.0.0.1:55432/sosnet_test",
)

_admin_engine = create_engine(TEST_ADMIN_DATABASE_URL, pool_pre_ping=True)


class TestConfig:
    TESTING = True
    DEBUG = False
    SECRET_KEY = "test-secret-key-with-enough-length-32"
    JWT_SECRET_KEY = "test-jwt-secret-key-with-enough-length-32"
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=1)
    SQLALCHEMY_DATABASE_URI = TEST_DATABASE_URL
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    AUTO_CREATE_TABLES = False
    CORS_ORIGINS = ["http://localhost:1010"]
    RATELIMIT_ENABLED = False
    SOS_RETENTION_DAYS = 90


def _password(value):
    return generate_password_hash(value, method="pbkdf2:sha256:1000")


def _reset_database():
    with _admin_engine.begin() as connection:
        connection.execute(
            text(
                """
                TRUNCATE
                    public.solicitudes_sos,
                    public.registros_comunicacion,
                    public.tipos_emergencia,
                    public.dispositivos,
                    public.usuarios,
                    public.configuracion_central,
                    auditoria.historial_estados,
                    auditoria.actividad
                RESTART IDENTITY CASCADE
                """
            )
        )
        connection.execute(
            text("SELECT set_config('app.audit_enabled', 'false', true)")
        )

        connection.execute(
            text(
                """
                INSERT INTO public.tipos_emergencia (nombre, descripcion) VALUES
                    ('Inundación', 'Viviendas o zonas afectadas por agua'),
                    ('Asistencia médica', 'Personas que necesitan atención médica urgente'),
                    ('Evacuación', 'Traslado de personas a un lugar seguro'),
                    ('Suministros', 'Agua, alimentos u otros insumos básicos'),
                    ('Otra', 'Emergencia no clasificada')
                """
            )
        )

        connection.execute(
            text(
                """
                INSERT INTO public.dispositivos (codigo, nombre, tipo, estado) VALUES
                    ('FORMULARIO-SOS', 'Formulario web SOS', 'web', 'activo')
                """
            )
        )

        connection.execute(
            text(
                """
                INSERT INTO public.usuarios (
                    nombre, usuario, correo, contrasena, rol, activo, fecha_registro
                ) VALUES
                    (:operador_nombre, 'operador', 'operador@sosnet.local',
                     :operador_hash, 'operador', true, now()),
                    (:admin_nombre, 'admin', 'admin@sosnet.local',
                     :admin_hash, 'admin', true, now()),
                    ('Cuenta inactiva', 'inactivo', 'inactivo@sosnet.local',
                     :inactivo_hash, 'operador', false, now()),
                    ('Sistema SOSNET', 'sistema', NULL, '!', 'sistema', false, now())
                """
            ),
            {
                "operador_nombre": "Operador SOSNET",
                "operador_hash": _password("OperadorDemo123"),
                "admin_nombre": "Administrador SOSNET",
                "admin_hash": _password("AdminDemo123"),
                "inactivo_hash": _password("InactivoDemo123"),
            },
        )

        connection.execute(
            text(
                """
                INSERT INTO public.configuracion_central (
                    id_configuracion, nombre, ubicacion, actualizado_en
                ) VALUES (1, 'Central de rescate', 'Asunción, Paraguay', now())
                """
            )
        )


@pytest.fixture
def app():
    _reset_database()
    application = create_app(TestConfig)
    with application.app_context():
        yield application
        db.session.remove()


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
