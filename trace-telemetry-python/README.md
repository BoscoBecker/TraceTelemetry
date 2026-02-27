# Trace Telemetry – SDK Python

SDK de telemetria em Python, compatível com a API e o contrato do pacote **TraceTelemetry.Client** (.NET). Offline-first: eventos são gravados em fila NDJSON e enviados em lotes por timer.

## Instalação

No diretório do repositório (`trace-telemetry-python`):

```bash
pip install -e .
```

Ou a partir do repositório:

```bash
pip install git+https://github.com/your-org/trace-telemetry-python.git
```

**Dependência:** `requests >= 2.28.0`, Python >= 3.8.

## Como usar o SDK

1. Crie opções com `TelemetryOptions` (endpoint da API, api_key, nome/versão do app, etc.).
2. Instancie `TelemetryClient(options)` e chame `client.start()` para ativar o timer de envio.
3. Use `client.track(...)` para registrar eventos e `client.track_exception(ex)` para exceções.
4. Opcionalmente chame `client.flush()` para forçar o envio imediato de um lote.
5. Ao encerrar, chame `client.stop()` (e, se quiser enviar o que restar, `client.flush()` antes).

## POC / Exemplo completo

O diretório `examples/` contém um script POC que você pode rodar para testar o SDK (modo one-shot ou loop).

```bash
# Na raiz de trace-telemetry-python, com o SDK instalado (pip install -e .)
python examples/poc.py
```

**Modo one-shot (padrão):** enfileira vários eventos, uma exceção simulada, faz flush e para.

**Modo loop:** defina `RUN_LOOP=true` e, opcionalmente, `LOOP_INTERVAL=5` (segundos):

```bash
RUN_LOOP=true LOOP_INTERVAL=5 python examples/poc.py
```

Variáveis de ambiente suportadas pela POC:

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `TELEMETRY_API_URL` | Base da API (ex.: `https://boscobecker.fun/`) | `https://boscobecker.fun/` |
| `TELEMETRY_API_KEY` | Chave enviada no header `X-API-Key` | (vazio) |
| `RUN_LOOP` | `true` = envia lotes em loop | `false` |
| `LOOP_INTERVAL` | Segundos entre rodadas (quando RUN_LOOP=true) | `5` |
| `BATCH_SIZE` | Eventos por lote no flush | `5` |
| `FLUSH_INTERVAL` | Intervalo do timer de flush (segundos) | `3` |

## Uso rápido (código)

```python
from trace_telemetry import TelemetryClient, TelemetryOptions

options = TelemetryOptions(
    endpoint_url="https://sua-api.com/telemetry",
    api_key="sua-api-key",  # opcional
    application_name="MeuServico",
    application_version="1.0.0",
    batch_size=20,
    flush_interval_seconds=10,
    queue_path="telemetry-queue.ndjson",
)

client = TelemetryClient(options)
client.start()

# Rastrear eventos
client.track("page_view")
client.track("purchase", {"order_id": "123", "amount": 99.90})
client.track("signup", "source", "google")

# Exceções (mensagem, stack trace, tipo)
try:
    risky_operation()
except Exception as ex:
    client.track_exception(ex, event_name="exception", extra_data={"step": "checkout"})

# Enviar fila manualmente (opcional)
client.flush()

# Ao encerrar o serviço
client.stop()
```

## Opções (`TelemetryOptions`)

| Opção | Descrição | Padrão |
|-------|-----------|--------|
| `endpoint_url` | URL do POST da API (ex.: `.../telemetry`) | `""` |
| `api_key` | Chave enviada no header `X-API-Key` | `""` |
| `queue_path` | Caminho do arquivo NDJSON da fila | `telemetry-queue.ndjson` |
| `batch_size` | Máximo de eventos por lote no flush | `20` |
| `flush_interval_seconds` | Intervalo do timer de flush (segundos, mín. 1) | `10` |
| `application_name` | Nome da aplicação em cada evento | `""` |
| `application_version` | Versão (ex.: `1.0.0`) | `""` |
| `enable_country_lookup` | Resolver país por IP (não implementado; reservado) | `False` |

## API do cliente

- **`start()`** – Inicia o timer que chama `flush()` a cada `flush_interval_seconds`. Deve ser chamado uma vez após criar o cliente.
- **`stop()`** – Para o timer. Não faz flush; chame `flush()` antes se quiser enviar o que restar na fila.
- **`flush()`** – Lê um lote da fila, envia via HTTP; em sucesso remove os eventos da fila. Nunca lança exceção.
- **`track(name)`** – Evento sem dados.
- **`track(name, data)`** – Evento com `data` (dict ou qualquer valor JSON-serializável).
- **`track(name, property_name, property_value)`** – Evento com um único par chave/valor.
- **`track_exception(exc, event_name="exception", extra_data=None)`** – Envia mensagem, stack trace e tipo da exceção; `extra_data` é opcional.
- **`queued_count`** – Propriedade que retorna o número aproximado de eventos na fila (diagnóstico).

O cliente é thread-safe e não propaga exceções nas operações de fila e envio.

## Formato dos eventos (API)

Cada evento enviado ao servidor segue o contrato do TraceTelemetry.Client: `id`, `name`, `timestampUtc` (ISO UTC), `data`, `applicationName`, `applicationVersion`, `machineName`, `osDescription`, `ipAddress`, `countryCode` (camelCase). O SDK preenche automaticamente máquina, SO e IP local; `countryCode` fica vazio salvo uso futuro de `enable_country_lookup`.
