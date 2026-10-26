from flask import Flask
from flask_cors import CORS

from .config import Config
from .extensions import db
from .routes import api
from .serial_reader import start_serial_reader


def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    db.init_app(app)
    CORS(app, resources={r"/api/*": {"origins": app.config["CORS_ORIGINS"]}})
    app.register_blueprint(api, url_prefix="/api")

    with app.app_context():
        db.create_all()

    if app.config["SERIAL_ENABLED"]:
        start_serial_reader(app)

    return app

