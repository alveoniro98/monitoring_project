import os


def configure_telemetry(app):
    endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
    if not endpoint:
        app.extensions["opentelemetry_enabled"] = False
        return

    try:
        from opentelemetry import trace
        from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
        from opentelemetry.instrumentation.flask import FlaskInstrumentor
        from opentelemetry.sdk.resources import Resource
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor
    except ImportError as error:
        raise RuntimeError(
            "OpenTelemetry endpoint is configured but optional packages are missing; "
            "install requirements-otel.txt"
        ) from error

    provider = TracerProvider(resource=Resource.create({"service.name": "opspulse"}))
    provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint=f"{endpoint.rstrip('/')}/v1/traces"))
    )
    trace.set_tracer_provider(provider)
    FlaskInstrumentor().instrument_app(app)
    app.extensions["opentelemetry_enabled"] = True
