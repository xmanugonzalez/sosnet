from flask import Blueprint, jsonify, request
from sqlalchemy import text

from .extensions import db
from .models import SolicitudSOS
from .services import (
    VALID_PRIORITIES,
    VALID_STATUSES,
    registrar_historial,
    registrar_solicitud,
)

api = Blueprint("api", __name__)

_INVALID = object()


def _parse_coordinate(value, minimum, maximum):
    if value is None or value == "":
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return _INVALID
    if number < minimum or number > maximum:
        return _INVALID
    return number


@api.get("/health")
def health():
    database = "connected"
    status_code = 200
    try:
        db.session.execute(text("SELECT 1"))
    except Exception:
        database = "unavailable"
        status_code = 503

    return jsonify({"service": "sosnet-api", "status": "ok", "database": database}), status_code


@api.get("/emergencies")
def list_emergencies():
    query = SolicitudSOS.query
    status = request.args.get("status")
    if status:
        if status not in VALID_STATUSES:
            return jsonify({"error": "Estado no válido"}), 400
        query = query.filter_by(estado=status)

    solicitudes = query.order_by(SolicitudSOS.fecha_recepcion.desc()).limit(100).all()
    return jsonify([solicitud.to_dict() for solicitud in solicitudes])


@api.post("/emergencies")
def create_emergency():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"error": "Se esperaba un JSON válido"}), 400

    emergency_type = str(payload.get("emergency_type") or payload.get("type") or "").strip()
    if not emergency_type:
        return jsonify({"error": "El tipo de emergencia es obligatorio"}), 400

    try:
        people = int(payload.get("people", 1))
    except (TypeError, ValueError):
        return jsonify({"error": "La cantidad de personas debe ser un número"}), 400
    if people < 1 or people > 1000:
        return jsonify({"error": "La cantidad de personas debe estar entre 1 y 1000"}), 400

    priority = str(payload.get("priority") or "media").strip().lower()
    if priority not in VALID_PRIORITIES:
        return jsonify({"error": "La prioridad debe ser alta, media o baja"}), 400

    latitude = _parse_coordinate(payload.get("latitude"), -90, 90)
    longitude = _parse_coordinate(payload.get("longitude"), -180, 180)
    if latitude is _INVALID or longitude is _INVALID:
        return jsonify({"error": "Las coordenadas no son válidas"}), 400

    solicitud = registrar_solicitud(
        {
            "emergency_type": emergency_type[:100],
            "device_id": str(payload.get("device_id") or "WEB").strip()[:50] or "WEB",
            "message": str(payload.get("message") or "").strip(),
            "reporter_name": str(payload.get("reporter_name") or "").strip(),
            "location": str(payload.get("location") or "").strip(),
            "people": people,
            "priority": priority,
            "latitude": latitude,
            "longitude": longitude,
        }
    )

    return jsonify(solicitud.to_dict()), 201


@api.patch("/emergencies/<int:emergency_id>")
def update_emergency(emergency_id):
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"error": "Se esperaba un JSON válido"}), 400

    solicitud = db.session.get(SolicitudSOS, emergency_id)
    if solicitud is None:
        return jsonify({"error": "Emergencia no encontrada"}), 404

    if "status" in payload:
        status = str(payload["status"]).strip().lower()
        if status not in VALID_STATUSES:
            return jsonify({"error": "Estado no válido"}), 400
        if status != solicitud.estado:
            estado_anterior = solicitud.estado
            solicitud.estado = status
            registrar_historial(solicitud, estado_anterior, status)

    if "priority" in payload:
        priority = str(payload["priority"]).strip().lower()
        if priority not in VALID_PRIORITIES:
            return jsonify({"error": "La prioridad debe ser alta, media o baja"}), 400
        solicitud.prioridad = priority

    db.session.commit()
    return jsonify(solicitud.to_dict())
