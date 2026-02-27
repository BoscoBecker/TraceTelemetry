"""
Telemetry client: offline-first, enqueue to NDJSON, flush in batches on a timer.
Thread-safe. Same API surface as TraceTelemetry.Client (.NET).
"""

import socket
import threading
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from trace_telemetry.options import TelemetryOptions
from trace_telemetry.queue import FileTelemetryQueue
from trace_telemetry.transport import send_batch


def _machine_name() -> str:
    try:
        return socket.gethostname() or ""
    except Exception:
        return ""


def _os_description() -> str:
    try:
        import platform
        return platform.platform() or ""
    except Exception:
        return ""


def _local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0.1)
        try:
            s.connect(("10.254.254.254", 1))
            return s.getsockname()[0] or ""
        except Exception:
            return ""
        finally:
            s.close()
    except Exception:
        return ""


def _build_event(
    name: str,
    data: Any,
    options: TelemetryOptions,
) -> Dict[str, Any]:
    """Build event dict with camelCase keys for API compatibility."""
    now = datetime.now(timezone.utc)
    # API expects camelCase; requests will serialize as-is
    ev = {
        "id": uuid.uuid4().hex,
        "name": name or "",
        "timestampUtc": now.isoformat().replace("+00:00", "Z"),
        "data": data,
        "applicationName": (options.application_name or "").strip(),
        "applicationVersion": (options.application_version or "").strip(),
        "machineName": _machine_name(),
        "osDescription": _os_description(),
        "ipAddress": _local_ip(),
        "countryCode": "",
    }
    return ev


class TelemetryClient:
    """
    Offline-first telemetry client: enqueues to NDJSON file, flushes in batches on a timer.
    Thread-safe. Compatible with TraceTelemetry.Client (.NET) and the same API.
    """

    def __init__(self, options: TelemetryOptions):
        if options is None:
            raise ValueError("options is required")
        self._options = options
        self._queue = FileTelemetryQueue(options.queue_path)
        self._flush_lock = threading.Lock()
        self._timer: Optional[object] = None
        self._started = False
        self._disposed = False
        self._timer_thread: Optional[threading.Thread] = None
        self._stop_timer = threading.Event()

    def start(self) -> None:
        """Start the automatic flush timer. Call once after creating the client."""
        if self._started or self._disposed:
            return
        self._started = True
        interval = max(1, self._options.flush_interval_seconds)

        def timer_loop():
            while not self._stop_timer.wait(timeout=interval):
                if self._disposed:
                    break
                if self._flush_lock.acquire(blocking=False):
                    try:
                        self.flush()
                    except Exception:
                        pass
                    finally:
                        self._flush_lock.release()

        self._timer_thread = threading.Thread(target=timer_loop, daemon=True)
        self._timer_thread.start()

    def stop(self) -> None:
        """Stop the timer. Does not flush remaining events (call flush() first if needed)."""
        self._started = False
        self._disposed = True
        self._stop_timer.set()
        if self._timer_thread and self._timer_thread.is_alive():
            self._timer_thread.join(timeout=2.0)

    def flush(self) -> None:
        """
        Try to send one batch to the API.
        Removes from queue only on success. Never raises.
        """
        batch, lines_to_remove = self._queue.peek_batch(self._options.batch_size)
        if not batch or lines_to_remove <= 0:
            return
        sent = send_batch(
            batch,
            self._options.endpoint_url,
            self._options.api_key,
        )
        if sent and lines_to_remove > 0:
            self._queue.remove_first(lines_to_remove)

    def track(self, name: str, data_or_key: Any = None, value: Any = None) -> None:
        """
        Track an event by name. Thread-safe, offline-first (writes to NDJSON queue).
        Signatures:
          track(name)
          track(name, data)           -- data: dict or any JSON-serializable value
          track(name, property_name, property_value)
        """
        try:
            if value is not None and data_or_key is not None and not isinstance(data_or_key, dict):
                data = {str(data_or_key): value}
            else:
                data = data_or_key
            ev = _build_event(name or "", data, self._options)
            self._queue.enqueue(ev)
        except Exception:
            pass

    def track_exception(
        self,
        exc: BaseException,
        event_name: str = "exception",
        extra_data: Any = None,
    ) -> None:
        """Track an exception with message, stack trace and type. Never raises."""
        if exc is None:
            return
        try:
            import traceback
            data = {
                "message": str(getattr(exc, "message", exc.args[0] if exc.args else "")),
                "stackTrace": traceback.format_exc(),
                "exceptionType": type(exc).__name__,
            }
            if hasattr(exc, "__cause__") and exc.__cause__:
                data["innerMessage"] = str(exc.__cause__)
            if extra_data is not None:
                if isinstance(extra_data, dict):
                    data.update(extra_data)
                else:
                    data["extra"] = extra_data
            ev = _build_event(event_name, data, self._options)
            self._queue.enqueue(ev)
        except Exception:
            pass

    @property
    def queued_count(self) -> int:
        """Current number of events in the queue (approximate, for diagnostics)."""
        return self._queue.peek_count()
