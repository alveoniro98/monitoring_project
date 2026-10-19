import os
import platform
import re
from datetime import datetime, timezone

from flask import Blueprint, current_app, jsonify, render_template

from app.monitoring import build_metrics_payload

bp = Blueprint("main", __name__)
_SAFE_RELEASE = re.compile(r"^[A-Za-z0-9._-]{1,80}$")


@bp.get("/")
def dashboard():
    return render_template("index.html")


@bp.get("/health")
def health():
    return jsonify(
        {
            "status": "healthy",
            "checks": {"application": {"status": "healthy"}},
            "checked_at": datetime.now(timezone.utc).isoformat(),
        }
    ), 200


@bp.get("/api/metrics")
def metrics_api():
    try:
        payload = build_metrics_payload()
    except Exception:
        current_app.logger.exception("Failed to collect runtime metrics")
        return jsonify({"status": "error", "error": "Metrics are temporarily unavailable"}), 503
    return jsonify(payload), 200


@bp.get("/api/info")
def info():
    release = os.getenv("OPSPULSE_RELEASE")
    if release and not _SAFE_RELEASE.fullmatch(release):
        release = None
    return jsonify(
        {
            "name": "OpsPulse",
            "version": release or "unknown",
            "runtime": platform.python_version(),
            "platform": platform.system(),
            "deployment": {
                "status": "available" if release else "not_configured",
                "release": release,
            },
        }
    ), 200