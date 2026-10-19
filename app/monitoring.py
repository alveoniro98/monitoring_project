import os
import time
from datetime import datetime, timezone

import psutil
from prometheus_client import Gauge

from app.cloudwatch import get_ec2_cpu_metric


PROCESS = psutil.Process()
PROCESS_STARTED_AT = time.time()
PROCESS_CPU = Gauge("opspulse_process_cpu_percent", "CPU utilization of the OpsPulse process")
PROCESS_MEMORY = Gauge("opspulse_process_memory_rss_bytes", "RSS memory of the OpsPulse process in bytes")
FILESYSTEM_USED = Gauge("opspulse_filesystem_used_percent", "Usage of the filesystem visible to the process")
PROCESS_UPTIME = Gauge("opspulse_process_uptime_seconds", "OpsPulse process uptime in seconds")


def _measurement(value, unit, scope="application process"):
    return {"value": value, "unit": unit, "scope": scope, "status": "available"}


def _unavailable(unit, scope="application process"):
    return {"value": None, "unit": unit, "scope": scope, "status": "unavailable"}


def collect_metrics():
    metrics = {}
    try:
        metrics["cpu_percent"] = _measurement(
            round(PROCESS.cpu_percent(interval=None), 2), "percent"
        )
    except (psutil.Error, OSError):
        metrics["cpu_percent"] = _unavailable("percent")

    try:
        memory = PROCESS.memory_info()
        metrics["memory_rss_bytes"] = _measurement(memory.rss, "bytes")
    except (psutil.Error, OSError):
        metrics["memory_rss_bytes"] = _unavailable("bytes")

    try:
        disk = psutil.disk_usage(os.environ.get("OPSPULSE_DISK_PATH", os.getcwd()))
        metrics["disk_percent"] = _measurement(
            round(disk.percent, 2), "percent", "filesystem visible to process"
        )
    except (psutil.Error, OSError):
        metrics["disk_percent"] = _unavailable(
            "percent", "filesystem visible to process"
        )

    metrics["uptime_seconds"] = _measurement(
        max(0, int(time.time() - PROCESS_STARTED_AT)), "seconds"
    )
    for key, gauge in (
        ("cpu_percent", PROCESS_CPU),
        ("memory_rss_bytes", PROCESS_MEMORY),
        ("disk_percent", FILESYSTEM_USED),
        ("uptime_seconds", PROCESS_UPTIME),
    ):
        if metrics[key]["status"] == "available":
            gauge.set(metrics[key]["value"])
    return metrics


def integration_status():
    return {
        "prometheus": {"status": "available", "detail": "/metrics endpoint enabled"},
        "container": {
            "status": "not_configured",
            "detail": "Container health is not queried (Docker socket is not exposed)",
        },
        "cloudwatch": {
            "status": "configured" if os.getenv("AWS_CLOUDWATCH_INSTANCE_ID") else "not_configured",
            "detail": "Configuration is present; export/permissions are not verified"
            if os.getenv("AWS_CLOUDWATCH_INSTANCE_ID")
            else "Set AWS_CLOUDWATCH_INSTANCE_ID to enable optional collection",
        },
        "opentelemetry": {
            "status": "configured" if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") else "not_configured",
            "detail": "Endpoint configured; successful export is not verified"
            if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
            else "Set OTEL_EXPORTER_OTLP_ENDPOINT and install requirements-otel.txt",
        },
    }


def build_metrics_payload():
    cloudwatch_metric = get_ec2_cpu_metric()
    metrics = collect_metrics()
    if cloudwatch_metric["status"] == "available":
        metrics["cloudwatch_ec2_cpu_percent"] = {
            "value": cloudwatch_metric["value"],
            "unit": "percent",
            "scope": "EC2 instance",
            "status": "available",
        }
    return {
        "status": "ok",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "metrics": metrics,
        "integrations": {
            **integration_status(),
            "cloudwatch": {
                "status": cloudwatch_metric["status"],
                "detail": cloudwatch_metric.get("detail", "Recent EC2 CPU metric retrieved"),
            },
        },
    }