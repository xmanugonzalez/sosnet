import json
import logging
import threading
import time

import serial

from .extensions import db
from .services import registrar_solicitud

logger = logging.getLogger(__name__)


def _save_message(app, payload):
    if not isinstance(payload, dict):
        logger.warning("Mensaje serial ignorado: se esperaba un objeto JSON")
        return

    with app.app_context():
        try:
            solicitud = registrar_solicitud(payload)
        except Exception:
            db.session.rollback()
            logger.exception("No se pudo almacenar la solicitud recibida por serial")
            return

        logger.info(
            "Solicitud %s almacenada desde %s",
            solicitud.codigo_mensaje,
            solicitud.dispositivo.codigo,
        )


def _read_loop(app):
    port = app.config["SERIAL_PORT"]
    baudrate = app.config["SERIAL_BAUDRATE"]
    timeout = app.config["SERIAL_TIMEOUT"]

    while True:
        try:
            with serial.Serial(port, baudrate, timeout=timeout) as connection:
                logger.info("Receptor serial conectado en %s", port)
                while connection.is_open:
                    raw_line = connection.readline().decode("utf-8", errors="replace").strip()
                    if raw_line:
                        _save_message(app, json.loads(raw_line))
        except (serial.SerialException, json.JSONDecodeError, ValueError) as error:
            logger.warning("Error del receptor serial: %s. Reintentando...", error)
            time.sleep(3)


def start_serial_reader(app):
    thread = threading.Thread(target=_read_loop, args=(app,), name="serial-reader", daemon=True)
    thread.start()
    return thread
