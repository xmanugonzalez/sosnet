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


def test_update_emergency_records_operator(client, auth_headers):
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


def test_reports_summary_integrates_views_and_functions(client, auth_headers):
    client.post("/api/emergencies", json={"emergency_type": "Inundación"})
    client.post("/api/emergencies", json={"emergency_type": "Evacuación"})

    response = client.get("/api/reports/summary", headers=auth_headers)

    assert response.status_code == 200
    data = response.get_json()
    assert data["summary"]["total_solicitudes"] == 2
    assert data["summary"]["pendientes"] == 2
    assert data["summary"]["ultima_solicitud"]
    by_type = {item["type"]: item for item in data["by_type"]}
    assert by_type["Inundación"]["total"] == 1
    assert by_type["Evacuación"]["total"] == 1


def test_reports_summary_requires_auth(client):
    assert client.get("/api/reports/summary").status_code == 401


def test_emergency_history_uses_table_function(client, auth_headers):
    created = client.post(
        "/api/emergencies", json={"emergency_type": "Inundación"}
    ).get_json()
    client.patch(
        f"/api/emergencies/{created['id']}",
        json={"status": "in_progress"},
        headers=auth_headers,
    )

    response = client.get(
        f"/api/emergencies/{created['id']}/history", headers=auth_headers
    )

    assert response.status_code == 200
    history = response.get_json()
    assert len(history) == 1
    assert history[0]["previous_status"] == "pending"
    assert history[0]["new_status"] == "in_progress"
    assert history[0]["operator"] == "Operador SOSNET"
    assert history[0]["operator_role"] == "operador"


def test_operator_sees_history_changes_made_by_admin(
    client, auth_headers, admin_headers
):
    created = client.post(
        "/api/emergencies", json={"emergency_type": "Inundación"}
    ).get_json()
    client.patch(
        f"/api/emergencies/{created['id']}",
        json={"status": "in_progress"},
        headers=auth_headers,
    )
    client.patch(
        f"/api/emergencies/{created['id']}",
        json={"status": "resolved"},
        headers=admin_headers,
    )

    response = client.get(
        f"/api/emergencies/{created['id']}/history", headers=auth_headers
    )

    assert response.status_code == 200
    history = response.get_json()
    assert len(history) == 2
    assert history[0]["new_status"] == "in_progress"
    assert history[0]["operator"] == "Operador SOSNET"
    assert history[1]["new_status"] == "resolved"
    assert history[1]["operator"] == "Administrador SOSNET"


def test_emergency_history_missing(client, auth_headers):
    response = client.get("/api/emergencies/999/history", headers=auth_headers)

    assert response.status_code == 404
