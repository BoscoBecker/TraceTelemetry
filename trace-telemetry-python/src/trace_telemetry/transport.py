"""
HTTP transport: sends telemetry batch to the API (POST JSON array).
Same contract as TraceTelemetry.Client HttpTelemetryTransport.
"""

from typing import List

import certifi
import requests


def send_batch(
    events: List[dict],
    endpoint_url: str,
    api_key: str = "",
    timeout: int = 30,
) -> bool:
    """
    POST events as JSON array to endpoint_url.
    Returns True if sent successfully (2xx), False otherwise (offline/error).
    Never raises.
    """
    if not events or not (endpoint_url or "").strip():
        return True
    try:
        headers = {"Content-Type": "application/json"}
        if (api_key or "").strip():
            headers["X-API-Key"] = api_key.strip()
        resp = requests.post(
            endpoint_url.strip(),
            json=events,
            headers=headers,
            timeout=timeout,
            verify=False
        )
        return resp.ok
    except Exception as exception:
        print(f"Error sending batch: {exception}")
        return False
