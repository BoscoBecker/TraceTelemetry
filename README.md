# TraceTelemetry SDK

<img width="1920" height="941" alt="image" src="https://github.com/user-attachments/assets/0f1479f7-020b-4f5b-8848-9bf97e199393" />


SDK leve e **offline-first** de telemetria para aplicações .NET python e futuramente Delphi (via binding). Pensado para apps desktop que precisam enviar eventos mesmo sem conexão estável: os eventos são enfileirados em arquivo NDJSON e enviados em lotes para a API quando há rede.

A API feita 100% em dotnet está hospedada na hostinger 100% segura (https) end-to-ende futuramente será alterado o dominio pessoal para api.tracetelemetry.com, como 
é um MVP o banco de dados é SQLITE mas futuramente será PostgresSQL e o front-end hospedada na Vercel.

## Características

- **Offline-first**: eventos gravados em fila NDJSON local; envio em batch quando a API estiver disponível
- **Thread-safe**: uso seguro de múltiplas threads
- **Sem dependências pesadas**: apenas `System.Text.Json` (netstandard2.0) ou built-in no .NET 6+
- **Timer de flush**: envio automático em intervalo configurável
- **Lookup de país**: opcional, por IP (geolocalização em cache)
- **Rastreio de exceções**: método dedicado com message, stack trace e tipo

## Estrutura do repositório

| Projeto | Descrição |
|--------|-----------|
| **TraceTelemetry.Client** | Biblioteca SDK (.NET Standard 2.0 e .NET 6) |
| **TraceTelemetry.Poc** | Aplicação de exemplo que usa o SDK |
| **TraceTelemetry.API** | API que recebe os eventos (POST `/telemetry`) |
| **trace-telemetry-python** | SDK equivalente em Python |

## Instalação

### Referência de projeto

```xml
<ProjectReference Include="..\TraceTelemetry.Client\TraceTelemetry.Client.csproj" />
```

### NuGet (quando publicado)

```bash
dotnet add package TraceTelemetry.Client
```

Pacote: `TraceTelemetry.Client` (versão `0.1.0-alpha`).

### Recompilar e empacotar o SDK (.NET)

Para gerar o pacote NuGet localmente e usá-lo em outros projetos com `dotnet add package TraceTelemetry.Client`:

1. **Gerar o pacote** (na raiz do repositório ou na pasta do cliente):

   ```bash
   cd TraceTelemetry.Client
   dotnet pack -c Release
   ```

   O arquivo `.nupkg` será criado em `TraceTelemetry.Client/bin/Release/` (ex.: `TraceTelemetry.Client.0.1.0-alpha.nupkg`).

2. **Adicionar a pasta como fonte NuGet local** (uma vez por máquina ou por solução):

   ```bash
   dotnet nuget add source "D:\TraceTelemetry\TraceTelemetry.Client\bin\Release" --name LocalTraceTelemetry
   ```

   Ajuste o caminho se o repositório estiver em outro diretório.

3. **No projeto que consome o SDK:**

   ```bash
   dotnet add package TraceTelemetry.Client
   ```

   Se a fonte `LocalTraceTelemetry` estiver configurada, o pacote será restaurado a partir da pasta local.

**Alternativa:** criar um `nuget.config` na raiz da solução apontando a pasta local como fonte, para não depender do `dotnet nuget add source` global:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="LocalTraceTelemetry" value=".\TraceTelemetry.Client\bin\Release" />
  </packageSources>
</configuration>
```

Assim, qualquer projeto da solução pode usar `dotnet add package TraceTelemetry.Client` e o pacote será resolvido a partir da pasta local após o `dotnet pack`.

### Python

No diretório do SDK Python, instale em modo editável e execute a POC:

```bash
cd D:\TraceTelemetry\trace-telemetry-python
pip install -e . -q
python examples/poc.py
```

Ou em uma linha (PowerShell):

```powershell
cd D:\TraceTelemetry\trace-telemetry-python; pip install -e . -q; python examples/poc.py
```

Requisitos: Python >= 3.8, `requests >= 2.28.0`.

## Configuração

Use `TelemetryOptions` (C#) ou `TelemetryOptions` em `trace_telemetry.options` (Python) para configurar endpoint, chave de API e comportamento da fila:

| Propriedade (C#) / Atributo (Python) | Descrição | Padrão |
|--------------------------------------|-----------|--------|
| `EndpointUrl` / `endpoint_url` | URL da API (ex.: `https://sua-api.com/telemetry`) | — |
| `ApiKey` / `api_key` | Chave enviada no header `X-API-Key` | — |
| `QueuePath` / `queue_path` | Caminho do arquivo NDJSON da fila | `telemetry-queue.ndjson` |
| `BatchSize` / `batch_size` | Quantidade de eventos por lote no envio | `20` |
| `FlushIntervalSeconds` / `flush_interval_seconds` | Intervalo em segundos do timer de envio | `10` |
| `ApplicationName` / `application_name` | Nome da aplicação (enviado em cada evento) | — |
| `ApplicationVersion` / `application_version` | Versão (ex.: `1.0.0`) | — |
| `EnableCountryLookup` / `enable_country_lookup` | Resolver país por IP (geolocalização) | C#: `true` / Python: `False` |

## Uso básico

```csharp
using TraceTelemetry.Client;

var options = new TelemetryOptions
{
    EndpointUrl = "https://sua-api.com/telemetry",
    ApiKey = "sua-api-key",
    QueuePath = "telemetry-queue.ndjson",
    BatchSize = 20,
    FlushIntervalSeconds = 10,
    ApplicationName = "MeuApp",
    ApplicationVersion = "1.0.0"
};

var client = new TelemetryClient(options);
client.Start();

// Evento simples (só nome)
await client.TrackAsync("app_start");

// Evento com payload (objeto anônimo ou dicionário)
await client.TrackAsync("order_created", new { OrderId = 123, Amount = 99.90m });

// Evento com uma propriedade (atalho)
await client.TrackAsync("button_click", "ButtonName", "Save");

// Exceção (message, stack trace, tipo)
try
{
    // ...
}
catch (Exception ex)
{
    await client.TrackExceptionAsync(ex, "exception", new { Tela = "Checkout" });
}

// Flush manual (opcional)
await client.FlushAsync();

// Ao encerrar a aplicação
client.Stop();
```

### Python

```python
from trace_telemetry import TelemetryClient, TelemetryOptions

options = TelemetryOptions(
    endpoint_url="https://sua-api.com/telemetry",
    api_key="sua-api-key",
    queue_path="telemetry-queue.ndjson",
    batch_size=20,
    flush_interval_seconds=10,
    application_name="MeuApp",
    application_version="1.0.0",
)

client = TelemetryClient(options)
client.start()

# Evento simples (só nome)
client.track("app_start")

# Evento com payload (dict ou valor JSON-serializável)
client.track("order_created", {"order_id": 123, "amount": 99.90})

# Evento com uma propriedade (atalho)
client.track("button_click", "button_name", "Save")

# Exceção (message, stack trace, tipo)
try:
    ...
except Exception as ex:
    client.track_exception(ex, event_name="exception", extra_data={"tela": "Checkout"})

# Flush manual (opcional)
client.flush()

# Ao encerrar a aplicação
client.stop()
```

## Modelo de evento

Cada evento enviado para a API contém (além do que você envia em `Data`):

- `Id`, `Name`, `TimestampUtc`
- `Data` (objeto ou dicionário que você passou)
- `ApplicationName`, `ApplicationVersion`
- `MachineName`, `OsDescription`
- `IpAddress`, `CountryCode` (quando `EnableCountryLookup` está ativo)

A API espera **POST** no endpoint configurado, corpo **JSON** com um **array de eventos**.

##Exceptions
1. **Captura** Trace Telemetry foi pensado para capturar exceptions e exibir de forma simples e rastreável, conforme abaixo

<img width="1916" height="936" alt="image" src="https://github.com/user-attachments/assets/002ee56c-a6c0-4480-8abf-af8318f87ff7" />


## Fila e envio

1. **Enfileiramento**: `TrackAsync` e `TrackExceptionAsync` gravam uma linha JSON no arquivo de fila (NDJSON). Não fazem rede.
2. **Timer**: após `Start()`, um timer chama o flush a cada `FlushIntervalSeconds`.
3. **Flush**: lê até `BatchSize` eventos do início da fila, envia **POST** para `EndpointUrl` com header `X-API-Key`; só remove da fila se a resposta for sucesso (2xx).
4. **Offline**: se der erro de rede ou API, os eventos permanecem na fila e serão reenviados no próximo ciclo.

## Transporte e fila customizados

Você pode injetar implementações próprias de fila e transporte:

```csharp
var client = new TelemetryClient(options, minhaFila, meuTransporte);
```

- **ITelemetryQueue**: `EnqueueAsync`, `PeekBatch`, `RemoveFirst`, `PeekCount`
- **ITelemetryTransport**: `SendBatchAsync(TelemetryEvent[] events)` — retorna `true` se enviou com sucesso

Para testes ou ambiente sem API, pode usar `FileDumpTransport` (grava lotes em arquivos NDJSON na pasta indicada).

## Requisitos

- **.NET Standard 2.0** ou **.NET 6+**
- Para .NET Standard 2.0 é usado o pacote `System.Text.Json` (versão 8.x)

## Licença

MIT.
