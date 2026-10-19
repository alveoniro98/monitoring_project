import logging
import os
from flask import Flask

from app.metrics import register_metrics
from app.routes import bp
from app.telemetry import configure_telemetry


def create_app(test_config=None):
    app = Flask(__name__)
    app.config.from_mapping(
        TESTING=False,
    )
    if test_config:
        app.config.update(test_config)

    logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"))
    app.register_blueprint(bp)
    register_metrics(app)
    configure_telemetry(app)
    return app