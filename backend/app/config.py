import os
from datetime import timedelta

from dotenv import load_dotenv

load_dotenv()


def _env_bool(name, default=False):
    return os.getenv(name, str(default)).lower() == "true"


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY") or "dev-only-secret"
    DEBUG = _env_bool("FLASK_DEBUG", False)

    # PostgreSQL directo (desarrollo) o Supabase (producción).
    # Ejemplo Supabase:
    # postgresql+psycopg://sosnet_api:PASSWORD@aws-0-region.pooler.supabase.com:5432/postgres?sslmode=require
    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL",
        "postgresql+psycopg://sosnet_api:sosnet_api_dev@127.0.0.1:5432/sosnet",
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        "pool_pre_ping": True,
        "pool_recycle": 280,
    }

    # En PostgreSQL las tablas se crean con database/*.sql. create_all solo se
    # usa en entornos de prueba que lo soliciten explícitamente.
    AUTO_CREATE_TABLES = _env_bool("AUTO_CREATE_TABLES", False)

    CORS_ORIGINS = [
        origin.strip()
        for origin in os.getenv(
            "CORS_ORIGINS", "http://localhost:1010,http://localhost:5173"
        ).split(",")
        if origin.strip()
    ]
    SERIAL_ENABLED = _env_bool("SERIAL_ENABLED", False)
    SERIAL_PORT = os.getenv("SERIAL_PORT", "COM3")
    SERIAL_BAUDRATE = int(os.getenv("SERIAL_BAUDRATE", "115200"))
    SERIAL_TIMEOUT = float(os.getenv("SERIAL_TIMEOUT", "1"))

    JWT_SECRET_KEY = (
        os.getenv("JWT_SECRET_KEY") or "dev-only-jwt-secret-change-me-1234567890"
    )
    JWT_TOKEN_LOCATION = ["headers"]
    JWT_HEADER_TYPE = "Bearer"
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(
        hours=int(os.getenv("JWT_ACCESS_TOKEN_HOURS") or "8")
    )

    RATELIMIT_STORAGE_URI = os.getenv("RATELIMIT_STORAGE_URI", "memory://")
    RATELIMIT_HEADERS_ENABLED = True
    RATELIMIT_ENABLED = _env_bool("RATELIMIT_ENABLED", True)

    SOS_RETENTION_DAYS = int(os.getenv("SOS_RETENTION_DAYS") or "90")
