def test_dashboard_renders(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"OpsPulse" in response.data


def test_health_reports_only_application_process(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json["status"] == "healthy"
    assert response.json["checks"]["application"]["status"] == "healthy"


def test_info_does_not_expose_environment(client, monkeypatch):
    monkeypatch.setenv("FLASK_SECRET_KEY", "never-return-this")
    response = client.get("/api/info")
    assert response.status_code == 200
    assert b"never-return-this" not in response.data


def test_info_rejects_unsafe_release_value(client, monkeypatch):
    monkeypatch.setenv("OPSPULSE_RELEASE", "tag\ninjected")
    assert client.get("/api/info").json["deployment"]["release"] is None


def test_metrics_failure_is_safe(client, monkeypatch):
    def fail():
        raise RuntimeError("private details")

    monkeypatch.setattr("app.routes.build_metrics_payload", fail)
    response = client.get("/api/metrics")
    assert response.status_code == 503
    assert response.json == {"status": "error", "error": "Metrics are temporarily unavailable"}
    assert b"private details" not in response.data