from app.models import Actividad, HistorialEstado, Usuario


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


def test_list_emergencies_requires_auth(client):
    response = client.get("/api/emergencies")

    assert response.status_code == 401
    assert response.get_json()["error"] == "Token de acceso requerido"


def test_list_emergencies_returns_created(client, auth_headers):
    client.post("/api/emergencies", json={"emergency_type": "Asistencia médica"})

    response = client.get("/api/emergencies", headers=auth_headers)

    assert response.status_code == 200
    emergencies = response.get_json()
    assert len(emergencies) == 1
    assert emergencies[0]["emergency_type"] == "Asistencia médica"


def test_update_emergency_status(client, auth_headers):
    created = client.post(
        "/api/emergencies", json={"emergency_type": "Inundación"}
    ).get_json()

    response = client.patch(
        f"/api/emergencies/{created['id']}",
        json={"status": "in_progress"},
        headers=auth_headers,
    )

    assert response.status_code == 200
    assert response.get_json()["status"] == "in_progress"


def test_update_emergency_records_operator(app, client, auth_headers):
    created = client.post(
        "/api/emergencies", json={"emergency_type": "Inundación"}
    ).get_json()
    client.patch(
        f"/api/emergencies/{created['id']}",
        json={"status": "resolved"},
        headers=auth_headers,
    )

    operator = Usuario.query.filter_by(correo="operador@sosnet.local").one()
    history = HistorialEstado.query.order_by(HistorialEstado.id_historial.desc()).first()
    activity = Actividad.query.filter_by(accion="emergency_status").first()

    assert history.id_usuario == operator.id_usuario
    assert history.estado_nuevo == "resolved"
    assert activity.id_usuario == operator.id_usuario
    assert activity.entidad_id == created["id"]


def test_update_emergency_rejects_invalid_status(client, auth_headers):
    created = client.post(
        "/api/emergencies", json={"emergency_type": "Inundación"}
    ).get_json()

    response = client.patch(
        f"/api/emergencies/{created['id']}",
        json={"status": "en camino"},
        headers=auth_headers,
    )

    assert response.status_code == 400


def test_update_missing_emergency(client, auth_headers):
    response = client.patch(
        "/api/emergencies/999", json={"status": "resolved"}, headers=auth_headers
    )

    assert response.status_code == 404
