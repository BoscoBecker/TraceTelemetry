#!/usr/bin/env python3
"""
POC do SDK Trace Telemetry em Python.

Uso:
  1. Instale o SDK no modo editável (na raiz de trace-telemetry-python):
       pip install -e .
  2. Execute a POC:
       python examples/poc.py

Variáveis de ambiente (opcionais):
  TELEMETRY_API_URL   Base da API (ex.: https://boscobecker.fun/)  [default: https://boscobecker.fun/]
  TELEMETRY_API_KEY   Chave X-API-Key                              [default: vazio]
  RUN_LOOP            true = envia lotes em loop a cada N segundos [default: false]
  LOOP_INTERVAL       Segundos entre cada rodada quando RUN_LOOP=true [default: 5]
  BATCH_SIZE          Eventos por lote no flush                    [default: 5]
  FLUSH_INTERVAL      Segundos do timer de flush                   [default: 3]
"""

import os
import signal
import sys
import tempfile
import time
import pip_system_certs.wrapt_requests

# Permite rodar a partir da raiz do projeto (trace-telemetry-python)
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from trace_telemetry import TelemetryClient, TelemetryOptions


def main():
    api_base = (os.environ.get("TELEMETRY_API_URL") or "https://boscobecker.fun/").rstrip("/")
    endpoint_url = f"{api_base}/telemetry"
    api_key = os.environ.get("TELEMETRY_API_KEY", "")
    run_loop = "true"
    loop_interval = max(1, int(os.environ.get("LOOP_INTERVAL", "5")))
    batch_size = max(1, int(os.environ.get("BATCH_SIZE", "5")))
    flush_interval = max(1, int(os.environ.get("FLUSH_INTERVAL", "3")))
    queue_dir = tempfile.mkdtemp(prefix="trace_telemetry_poc_")
    queue_path = os.path.join(queue_dir, "queue.ndjson")

    options = TelemetryOptions(
        endpoint_url=endpoint_url,
        api_key=api_key,
        queue_path=queue_path,
        batch_size=batch_size,
        flush_interval_seconds=flush_interval,
        application_name="PocAppPython",
        application_version="1.0.0",
    )

    client = TelemetryClient(options)
    client.start()

    print("Telemetry started. API:", endpoint_url)
    print("Queue:", queue_path)
    print("RunLoop:", run_loop, f"(interval: {loop_interval}s)" if run_loop else "")

    if run_loop:
        stop = False

        def on_signal(_, __):
            nonlocal stop
            stop = True

        signal.signal(signal.SIGINT, on_signal)
        if hasattr(signal, "SIGTERM"):
            signal.signal(signal.SIGTERM, on_signal)

        round_num = 0
        while not stop:
            round_num += 1
            client.track("poc_loop", {"round": round_num})
            client.track("order_created", {"order_id": 1000 + round_num, "amount": 10.0 * round_num})
            client.track("screen_view", {"screen": "Loop", "round": round_num})
            client.track("app_heartbeat", {"queued_count": client.queued_count})

            client.flush()
            print(f"[{time.strftime('%H:%M:%S')}] Round {round_num} enviado. QueuedCount = {client.queued_count}")

            for _ in range(loop_interval):
                if stop:
                    break
                time.sleep(1)

        client.stop()
        print("Loop encerrado.")
        return

    # Modo one-shot (RunLoop = false)
    client.track("machine_info", {"collected_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())})
    client.track("order_created", {"order_id": 123, "amount": 99.90})
    client.track("order_created", {"order_id": 124})
    client.track("screen_view", {"screen": "Dashboard"})
    client.track("button_click", "button_name", "Save")
    client.track("app_start")

    try:
        raise ValueError("Simulated POC exception for dashboard testing.")
    except Exception as ex:
        client.track_exception(ex, event_name="exception", extra_data={"source": "PocAppPython", "simulated": True})
        print("Exception tracked (stacktrace in dashboard).")

    print("Queued 7 events. QueuedCount =", client.queued_count)
    time.sleep(4)
    client.flush()
    print("After first flush, QueuedCount =", client.queued_count)

    client.track("order_created", {"order_id": 125})
    time.sleep(4)
    client.stop()
    print("Stopped.")


if __name__ == "__main__":
    main()
