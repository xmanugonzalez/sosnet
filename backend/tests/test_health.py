from app import create_app


class TestConfig:
    TESTING = True
    DEBUG = False
    SECRET_KEY = "test"
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    CORS_ORIGINS = ["http://localhost:5173"]
    SERIAL_ENABLED = False


def test_health_endpoint():
    app = create_app(TestConfig)
    response = app.test_client().get("/api/health")

    assert response.status_code == 200
    assert response.get_json() == {
        "database": "connected",
        "service": "sosnet-api",
        "status": "ok",
    }

