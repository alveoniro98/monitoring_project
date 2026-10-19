def test_metrics_api_has_expected_structure_and_real_ranges(client):
    response = client.get("/api/metrics")
    assert response.status_code == 200
    data = response.json
    assert data["status"] == "ok"
    assert data["generated_at"]
    assert set(data["metrics"]) == {
        "cpu_percent",
        "memory_rss_bytes",
        "disk_percent",
        "uptime_seconds",
    }
    if data["metrics"]["cpu_percent"]["status"] == "available":
        assert data["metrics"]["cpu_percent"]["value"] >= 0
    if data["metrics"]["disk_percent"]["status"] == "available":
        assert 0 <= data["metrics"]["disk_percent"]["value"] <= 100
    assert data["metrics"]["memory_rss_bytes"]["scope"] == "application process"
    assert data["integrations"]["cloudwatch"]["status"] == "not_configured"
    assert data["integrations"]["container"]["status"] == "not_configured"


def test_unavailable_metric_is_explicit(client, monkeypatch):
    def unavailable():
        return {
            "cpu_percent": {
                "value": None,
                "unit": "percent",
                "scope": "application process",
                "status": "unavailable",
            },
            "memory_rss_bytes": {
                "value": 1,
                "unit": "bytes",
                "scope": "application process",
                "status": "available",
            },
            "disk_percent": {
                "value": 2,
                "unit": "percent",
                "scope": "filesystem visible to process",
                "status": "available",
            },
            "uptime_seconds": {
                "value": 3,
                "unit": "seconds",
                "scope": "application process",
                "status": "available",
            },
        }

    monkeypatch.setattr("app.monitoring.collect_metrics", unavailable)
    response = client.get("/api/metrics")
    assert response.status_code == 200
    assert response.json["metrics"]["cpu_percent"]["status"] == "unavailable"
    assert response.json["metrics"]["cpu_percent"]["value"] is None


def test_prometheus_endpoint_exposes_application_metrics(client):
    client.get("/health")
    response = client.get("/metrics")
    assert response.status_code == 200
    assert b"opspulse_http_requests_total" in response.data


def test_required_routes_exist(client):
    for path in ("/", "/health", "/api/metrics", "/api/info", "/metrics"):
        assert client.get(path).status_code == 200