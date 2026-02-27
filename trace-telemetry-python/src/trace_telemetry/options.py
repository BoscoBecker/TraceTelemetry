"""Configuration options for the telemetry client (mirrors TraceTelemetry.Client TelemetryOptions)."""

from dataclasses import dataclass, field


@dataclass
class TelemetryOptions:
    """Options for TelemetryClient. Same semantics as .NET TelemetryOptions."""

    endpoint_url: str = "https://boscobecker.fun/"
    """URL of the telemetry API (e.g. https://api.example.com/telemetry). POST batch here."""

    api_key: str = "***"
    """Optional. Sent as X-API-Key header when non-empty."""

    queue_path: str = "telemetry-queue.ndjson"
    """Path to the NDJSON file used as offline queue."""

    batch_size: int = 20
    """Max events per flush batch."""

    flush_interval_seconds: int = 10
    """Interval in seconds for automatic flush (min 1)."""

    application_name: str = ""
    """Optional. Sent with every event for filtering in the API."""

    application_version: str = ""
    """Optional. e.g. '1.0.0'."""

    enable_country_lookup: bool = False
    """When True, resolve country code from IP (requires optional geo dependency). Default False for Python SDK."""
