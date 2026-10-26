from datetime import datetime, timezone

from .extensions import db


class Emergency(db.Model):
    __tablename__ = "emergencies"

    id = db.Column(db.Integer, primary_key=True)
    device_id = db.Column(db.String(64), nullable=False, index=True)
    emergency_type = db.Column(db.String(50), nullable=False, default="general")
    message = db.Column(db.String(500), nullable=False)
    latitude = db.Column(db.Numeric(10, 7), nullable=True)
    longitude = db.Column(db.Numeric(10, 7), nullable=True)
    status = db.Column(db.String(20), nullable=False, default="pending", index=True)
    received_at = db.Column(
        db.DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc)
    )

    def to_dict(self):
        return {
            "id": self.id,
            "device_id": self.device_id,
            "emergency_type": self.emergency_type,
            "message": self.message,
            "latitude": float(self.latitude) if self.latitude is not None else None,
            "longitude": float(self.longitude) if self.longitude is not None else None,
            "status": self.status,
            "received_at": self.received_at.isoformat(),
        }

