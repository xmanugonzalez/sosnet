from app.models import Actividad, Usuario


def login(client, identifier, password, role=None):
    payload = {"identifier": identifier, "password": password}
    if role:
        payload["role"] = role
    return client.post("/api/auth/login", json=payload)


def test_login_operator(client):
    response = login(client, "operador@sosnet.local", "OperadorDemo123", "operador")

    assert response.status_code == 200
    data = response.get_json()
    assert data["token"]
    assert data["user"]["email"] == "operador@sosnet.local"
    assert data["user"]["role"] == "operador"
    assert data["user"]["active"] is True
    assert "contrasena" not in data["user"]


def test_login_accepts_username(client):
    response = login(client, "operador", "OperadorDemo123")

    assert response.status_code == 200


def test_login_rejects_bad_password(client):
    response = login(client, "operador@sosnet.local", "incorrecta")

    assert response.status_code == 401


def test_login_rejects_role_mismatch(client):
    response = login(client, "operador@sosnet.local", "OperadorDemo123", "admin")

    assert response.status_code == 403


def test_login_rejects_inactive_user(client):
    response = login(client, "inactivo@sosnet.local", "InactivoDemo123")

    assert response.status_code == 401


def test_me_requires_valid_token(client):
    assert client.get("/api/auth/me").status_code == 401
    assert (
        client.get(
            "/api/auth/me", headers={"Authorization": "Bearer token-invalido"}
        ).status_code
        == 401
    )


def test_me_and_logout(client):
    token = login(client, "operador@sosnet.local", "OperadorDemo123").get_json()["token"]
    headers = {"Authorization": f"Bearer {token}"}

    response = client.get("/api/auth/me", headers=headers)
    assert response.status_code == 200
    assert response.get_json()["user"]["email"] == "operador@sosnet.local"

    response = client.post("/api/auth/logout", headers=headers)
    assert response.status_code == 204
    assert Actividad.query.filter_by(accion="logout").count() == 1


def test_operator_cannot_manage_users(client, auth_headers):
    response = client.get("/api/users", headers=auth_headers)

    assert response.status_code == 403


def test_admin_lists_users(client, admin_headers):
    response = client.get("/api/users", headers=admin_headers)

    assert response.status_code == 200
    users = response.get_json()
    assert len(users) == 3
    by_email = {user["email"]: user for user in users}
    assert by_email["admin@sosnet.local"]["role"] == "admin"
    assert by_email["operador@sosnet.local"]["active"] is True
    assert by_email["inactivo@sosnet.local"]["active"] is False


def test_admin_creates_and_deactivates_user(client, admin_headers):
    response = client.post(
        "/api/users",
        headers=admin_headers,
        json={
            "nombre": "Nueva Operadora",
            "correo": "nueva@sosnet.local",
            "password": "ClaveSegura123",
            "rol": "operador",
        },
    )

    assert response.status_code == 201
    created = response.get_json()
    assert created["role"] == "operador"
    assert created["active"] is True

    assert login(client, "nueva@sosnet.local", "ClaveSegura123").status_code == 200

    response = client.patch(
        f"/api/users/{created['id']}",
        headers=admin_headers,
        json={"activo": False},
    )
    assert response.status_code == 200
    assert response.get_json()["active"] is False
    assert login(client, "nueva@sosnet.local", "ClaveSegura123").status_code == 401

    assert Actividad.query.filter_by(accion="user_create").count() == 1
    assert Actividad.query.filter_by(accion="user_update").count() == 1


def test_admin_cannot_create_duplicate_user(client, admin_headers):
    response = client.post(
        "/api/users",
        headers=admin_headers,
        json={
            "nombre": "Duplicado",
            "correo": "operador@sosnet.local",
            "password": "ClaveSegura123",
        },
    )

    assert response.status_code == 409


def test_admin_cannot_create_user_with_short_password(client, admin_headers):
    response = client.post(
        "/api/users",
        headers=admin_headers,
        json={
            "nombre": "Clave corta",
            "correo": "corta@sosnet.local",
            "password": "123",
        },
    )

    assert response.status_code == 400


def test_admin_cannot_deactivate_self(client, admin_headers):
    admin = Usuario.query.filter_by(correo="admin@sosnet.local").one()

    response = client.patch(
        f"/api/users/{admin.id_usuario}",
        headers=admin_headers,
        json={"activo": False},
    )

    assert response.status_code == 400


def test_settings_permissions(client, auth_headers, admin_headers):
    response = client.get("/api/settings", headers=auth_headers)
    assert response.status_code == 200
    assert response.get_json()["name"] == "Central de rescate"

    forbidden = client.put(
        "/api/settings",
        headers=auth_headers,
        json={"name": "Otra central", "location": "Otro lugar"},
    )
    assert forbidden.status_code == 403

    updated = client.put(
        "/api/settings",
        headers=admin_headers,
        json={"name": "Central Norte", "location": "Encarnación"},
    )
    assert updated.status_code == 200
    assert updated.get_json()["name"] == "Central Norte"
    assert client.get("/api/settings", headers=admin_headers).get_json()["location"] == (
        "Encarnación"
    )


def test_activity_is_admin_only(client, auth_headers, admin_headers):
    assert client.get("/api/activity", headers=auth_headers).status_code == 403

    response = client.get("/api/activity", headers=admin_headers)
    assert response.status_code == 200
    events = response.get_json()
    assert events
    assert any(event["action"] == "login" for event in events)
