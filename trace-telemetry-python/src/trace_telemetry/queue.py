"""
File-based NDJSON queue for offline-first telemetry.
Thread-safe: append on enqueue, read + truncate on remove.
"""

import json
import os
import threading
from pathlib import Path
from typing import List, Tuple


class FileTelemetryQueue:
    """Thread-safe, NDJSON file-based queue. One JSON object per line."""

    def __init__(self, queue_path: str):
        self._path = (queue_path or "telemetry-queue.ndjson").strip()
        self._lock = threading.Lock()
        dir_path = Path(self._path).parent
        if str(dir_path) != ".":
            dir_path.mkdir(parents=True, exist_ok=True)

    def enqueue(self, event: dict) -> None:
        """Append one event (dict) as a single JSON line. Never raises."""
        if not event:
            return
        try:
            line = json.dumps(event, ensure_ascii=False, default=_json_default) + "\n"
            with self._lock:
                with open(self._path, "a", encoding="utf-8") as f:
                    f.write(line)
        except Exception:
            pass

    def peek_batch(self, max_items: int) -> Tuple[List[dict], int]:
        """
        Read up to max_items from the front without removing.
        Returns (list of event dicts, number of lines to remove on success).
        """
        if max_items <= 0:
            return ([], 0)
        try:
            with self._lock:
                if not os.path.isfile(self._path):
                    return ([], 0)
                with open(self._path, "r", encoding="utf-8") as f:
                    lines = f.readlines()
                if not lines:
                    return ([], 0)
                take = min(max_items, len(lines))
                batch = []
                for i in range(take):
                    line = lines[i].strip()
                    if not line:
                        continue
                    try:
                        evt = json.loads(line)
                        if evt:
                            batch.append(evt)
                    except Exception:
                        pass
                return (batch, take)
        except Exception:
            return ([], 0)

    def remove_first(self, count: int) -> None:
        """Remove the first count lines. Call only after successful API send."""
        if count <= 0:
            return
        try:
            with self._lock:
                if not os.path.isfile(self._path):
                    return
                with open(self._path, "r", encoding="utf-8") as f:
                    all_lines = f.readlines()
                if not all_lines:
                    return
                to_remove = min(count, len(all_lines))
                if to_remove >= len(all_lines):
                    try:
                        os.remove(self._path)
                    except Exception:
                        pass
                    return
                remaining = all_lines[to_remove:]
                with open(self._path, "w", encoding="utf-8") as f:
                    f.writelines(remaining)
        except Exception:
            pass

    def peek_count(self) -> int:
        """Approximate number of lines in the queue."""
        try:
            with self._lock:
                if not os.path.isfile(self._path):
                    return 0
                with open(self._path, "r", encoding="utf-8") as f:
                    return len(f.readlines())
        except Exception:
            return 0


def _json_default(obj):
    """JSON serializer for datetime etc."""
    from datetime import datetime
    if hasattr(obj, "isoformat"):
        return obj.isoformat()
    raise TypeError(f"Object of type {type(obj).__name__} is not JSON serializable")
