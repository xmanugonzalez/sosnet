from flask import Blueprint, jsonify
from sqlalchemy import text

from .extensions import db
from .models import Emergency

api = Blueprint("api", __name__)


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
    emergencies = Emergency.query.order_by(Emergency.received_at.desc()).limit(100).all()
    return jsonify([emergency.to_dict() for emergency in emergencies])

