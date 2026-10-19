import time

from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from flask import Response, request

REQUESTS = Counter(
    "opspulse_http_requests_total",
    "HTTP requests handled by OpsPulse",
    ("method", "endpoint", "status"),
)
REQUEST_DURATION = Histogram(
    "opspulse_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ("method", "endpoint"),
)


def register_metrics(app):
    @app.before_request
    def start_request_timer():
        request._opspulse_started_at = time.perf_counter()

    @app.after_request
    def record_request(response):
        endpoint = request.endpoint or "unknown"
        REQUESTS.labels(request.method, endpoint, str(response.status_code)).inc()
        started_at = getattr(request, "_opspulse_started_at", None)
        if started_at is not None:
            REQUEST_DURATION.labels(
                request.method, endpoint
            ).observe(time.perf_counter() - started_at)
        return response

    @app.get("/metrics")
    def prometheus_metrics():
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)
