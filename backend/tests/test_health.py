from app import create_app


class ProductionConfig:
    TESTING = False
    DEBUG = False
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    CORS_ORIGINS = ["http://localhost:1010"]
    SERIAL_ENABLED = False
    RATELIMIT_ENABLED = False
    SOS_RETENTION_DAYS = 90


def _production_app(secret_key, jwt_secret_key):
    class Config(ProductionConfig):
        SECRET_KEY = secret_key
        JWT_SECRET_KEY = jwt_secret_key

    return create_app(Config)


def test_health_endpoint(client):
    response = client.get("/api/health")

    assert response.status_code == 200
    assert response.get_json() == {
        "database": "connected",
        "service": "sosnet-api",
        "status": "ok",
    }


def test_production_blocks_default_or_shared_secrets():
    default_app = _production_app("dev-only-secret", "dev-only-secret")
    shared_app = _production_app(
        "clave-segura-para-sesiones-123456",
        "clave-segura-para-sesiones-123456",
    )

    assert default_app.test_client().get("/api/health").status_code == 503
    assert shared_app.test_client().get("/api/health").status_code == 503


def test_production_allows_distinct_custom_secrets():
    app = _production_app(
        "clave-segura-para-sesiones-123456",
        "clave-jwt-totalmente-distinta-7890",
    )

    assert app.test_client().get("/api/health").status_code == 200
