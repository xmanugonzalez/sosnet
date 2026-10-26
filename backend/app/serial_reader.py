import json
import logging
import threading
import time

import serial

from .extensions import db
from .models import Emergency

logger = logging.getLogger(__name__)


def _save_message(app, payload):
    with app.app_context():
        emergency = Emergency(
            device_id=str(payload.get("device_id", "unknown"))[:64],
            emergency_type=str(payload.get("type", "general"))[:50],
            message=str(payload.get("message", "Solicitud de emergencia"))[:500],
            latitude=payload.get("latitude"),
            longitude=payload.get("longitude"),
        )
        db.session.add(emergency)
        db.session.commit()
        logger.info("Emergencia %s almacenada desde %s", emergency.id, emergency.device_id)


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

