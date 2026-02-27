"""
Trace Telemetry SDK for Python.
Offline-first telemetry client: enqueues to NDJSON file, flushes in batches on a timer.
Compatible with the same API as TraceTelemetry.Client (.NET).
"""

from trace_telemetry.client import TelemetryClient
from trace_telemetry.options import TelemetryOptions

__all__ = ["TelemetryClient", "TelemetryOptions"]
__version__ = "0.1.0"
