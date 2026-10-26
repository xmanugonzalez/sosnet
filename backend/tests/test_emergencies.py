import pytest

from app import create_app


class TestConfig:
    TESTING = True
    DEBUG = False
    SECRET_KEY = "test"
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    CORS_ORIGINS = ["http://localhost:1010"]
    SERIAL_ENABLED = False


@pytest.fixture
def client():
    app = create_app(TestConfig)
    with app.app_context():
        yield app.test_client()


def test_create_emergency(client):
    response = client.post(
        "/api/emergencies",
        json={
            "emergency_type": "Inundación",
            "message": "El agua está entrando a la casa",
            "reporter_name": "María González",
            "location": "Barrio San Francisco",
            "people": 5,
            "priority": "alta",
            "latitude": -25.2867,
            "longitude": -57.3333,
        },
    )

    assert response.status_code == 201
    data = response.get_json()
    assert data["emergency_type"] == "Inundación"
    assert data["people"] == 5
    assert data["priority"] == "alta"
    assert data["status"] == "pending"
    assert data["reporter_name"] == "María González"
    assert data["location"].startswith("Barrio San Francisco")
    assert "GPS" in data["location"]


def test_create_emergency_requires_type(client):
    response = client.post("/api/emergencies", json={"people": 2})

    assert response.status_code == 400
    assert "tipo de emergencia" in response.get_json()["error"]


def test_create_emergency_rejects_invalid_people(client):
    response = client.post(
        "/api/emergencies", json={"emergency_type": "Evacuación", "people": 0}
    )

    assert response.status_code == 400


def test_create_emergency_rejects_invalid_priority(client):
    response = client.post(
        "/api/emergencies",
        json={"emergency_type": "Suministros", "priority": "urgentísima"},
    )

    assert response.status_code == 400


def test_create_emergency_rejects_invalid_coordinates(client):
    response = client.post(
        "/api/emergencies",
        json={"emergency_type": "Otra", "latitude": 200, "longitude": 0},
    )

    assert response.status_code == 400


def test_list_emergencies_returns_created(client):
    client.post("/api/emergencies", json={"emergency_type": "Asistencia médica"})

    response = client.get("/api/emergencies")

    assert response.status_code == 200
    emergencies = response.get_json()
    assert len(emergencies) == 1
    assert emergencies[0]["emergency_type"] == "Asistencia médica"


def test_update_emergency_status(client):
    created = client.post(
        "/api/emergencies", json={"emergency_type": "Inundación"}
    ).get_json()

    response = client.patch(
        f"/api/emergencies/{created['id']}", json={"status": "in_progress"}
    )

    assert response.status_code == 200
    assert response.get_json()["status"] == "in_progress"


def test_update_emergency_rejects_invalid_status(client):
    created = client.post(
        "/api/emergencies", json={"emergency_type": "Inundación"}
    ).get_json()

    response = client.patch(
        f"/api/emergencies/{created['id']}", json={"status": "en camino"}
    )

    assert response.status_code == 400


def test_update_missing_emergency(client):
    response = client.patch("/api/emergencies/999", json={"status": "resolved"})

    assert response.status_code == 404
