import os

from dotenv import load_dotenv

load_dotenv()


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-only-secret")
    DEBUG = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL", "mysql+pymysql://sosnet:sosnet_dev@127.0.0.1:3306/sosnet"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    CORS_ORIGINS = [
        origin.strip()
        for origin in os.getenv("CORS_ORIGINS", "http://localhost:5173").split(",")
        if origin.strip()
    ]
    SERIAL_ENABLED = os.getenv("SERIAL_ENABLED", "false").lower() == "true"
    SERIAL_PORT = os.getenv("SERIAL_PORT", "COM3")
    SERIAL_BAUDRATE = int(os.getenv("SERIAL_BAUDRATE", "115200"))
    SERIAL_TIMEOUT = float(os.getenv("SERIAL_TIMEOUT", "1"))

