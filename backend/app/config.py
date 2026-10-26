import os
from datetime import timedelta

from dotenv import load_dotenv

load_dotenv()


def _env_bool(name, default=False):
    return os.getenv(name, str(default)).lower() == "true"


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY") or "dev-only-secret"
    DEBUG = _env_bool("FLASK_DEBUG", False)
    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL", "mysql+pymysql://sosnet:sosnet_dev@127.0.0.1:3306/sosnet"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
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
