from flask import Blueprint, jsonify, request
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError

from .extensions import db, limiter
from .models import SolicitudSOS
from .security import auth_required, get_current_user
from .services import (
    VALID_PRIORITIES,
    VALID_STATUSES,
    actualizar_estado,
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


def _iso(value):
    return value.isoformat() if value is not None else None


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
@auth_required
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
@limiter.limit("30 per minute")
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

    return jsonify(solicitud), 201


@api.patch("/emergencies/<int:emergency_id>")
@auth_required
def update_emergency(emergency_id):
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"error": "Se esperaba un JSON válido"}), 400

    solicitud = db.session.get(SolicitudSOS, emergency_id)
    if solicitud is None:
        return jsonify({"error": "Emergencia no encontrada"}), 404

    new_status = None
    if "status" in payload:
        new_status = str(payload["status"]).strip().lower()
        if new_status not in VALID_STATUSES:
            return jsonify({"error": "Estado no válido"}), 400

    new_priority = None
    if "priority" in payload:
        new_priority = str(payload["priority"]).strip().lower()
        if new_priority not in VALID_PRIORITIES:
            return jsonify({"error": "La prioridad debe ser alta, media o baja"}), 400

    try:
        if new_status is not None and new_status != solicitud.estado:
            actualizar_estado(
                solicitud.id_solicitud,
                new_status,
                get_current_user(),
            )

        if new_priority is not None:
            solicitud.prioridad = new_priority

        db.session.commit()
        db.session.refresh(solicitud)
    except DBAPIError as error:
        db.session.rollback()
        sqlstate = getattr(error.orig, "sqlstate", None) or getattr(
            error.orig, "pgcode", None
        )
        if sqlstate == "P0002":
            return jsonify({"error": "Emergencia no encontrada"}), 404
        if sqlstate == "42501":
            return jsonify({"error": "No autorizado para cambiar esta emergencia"}), 403
        if sqlstate == "22023":
            return jsonify({"error": "Datos de emergencia no válidos"}), 400
        raise

    return jsonify(solicitud.to_dict())


@api.get("/emergencies/<int:emergency_id>/history")
@auth_required
def emergency_history(emergency_id):
    solicitud = db.session.get(SolicitudSOS, emergency_id)
    if solicitud is None:
        return jsonify({"error": "Emergencia no encontrada"}), 404

    rows = (
        db.session.execute(
            text("SELECT * FROM reportes.fn_historial_solicitud(:solicitud)"),
            {"solicitud": emergency_id},
        )
        .mappings()
        .all()
    )

    return jsonify(
        [
            {
                "id": row["id_historial"],
                "previous_status": row["estado_anterior"],
                "new_status": row["estado_nuevo"],
                "operator": row["usuario"],
                "operator_role": row["rol"],
                "changed_at": _iso(row["fecha_cambio"]),
                "note": row["observacion"],
            }
            for row in rows
        ]
    )


@api.get("/reports/summary")
@auth_required
def reports_summary():
    summary = (
        db.session.execute(
            text("SELECT * FROM reportes.vw_estadisticas_emergencias")
        )
        .mappings()
        .first()
    )
    by_type = (
        db.session.execute(text("SELECT * FROM reportes.fn_estadisticas_por_tipo()"))
        .mappings()
        .all()
    )

    data = dict(summary) if summary else {}
    data["ultima_solicitud"] = _iso(data.get("ultima_solicitud"))

    return jsonify(
        {
            "summary": data,
            "by_type": [
                {
                    "type": row["tipo"],
                    "total": row["total"],
                    "pending": row["pendientes"],
                    "in_progress": row["en_proceso"],
                    "resolved": row["resueltas"],
                    "people": row["personas"],
                }
                for row in by_type
            ],
        }
    )
