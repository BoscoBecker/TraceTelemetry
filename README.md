# TraceTelemetry SDK

SDK leve e **offline-first** de telemetria para aplicações .NET e Delphi (via binding). Pensado para apps desktop que precisam enviar eventos mesmo sem conexão estável: os eventos são enfileirados em arquivo NDJSON e enviados em lotes para a API quando há rede.

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

## Configuração

Use `TelemetryOptions` para configurar endpoint, chave de API e comportamento da fila:

| Propriedade | Descrição | Padrão |
|-------------|-----------|--------|
| `EndpointUrl` | URL da API (ex.: `https://sua-api.com/telemetry`) | — |
| `ApiKey` | Chave enviada no header `X-API-Key` | — |
| `QueuePath` | Caminho do arquivo NDJSON da fila | `telemetry-queue.ndjson` |
| `BatchSize` | Quantidade de eventos por lote no envio | `20` |
| `FlushIntervalSeconds` | Intervalo em segundos do timer de envio | `10` |
| `ApplicationName` | Nome da aplicação (enviado em cada evento) | — |
| `ApplicationVersion` | Versão (ex.: `1.0.0`) | — |
| `EnableCountryLookup` | Resolver país por IP (geolocalização) | `true` |

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

## Modelo de evento

Cada evento enviado para a API contém (além do que você envia em `Data`):

- `Id`, `Name`, `TimestampUtc`
- `Data` (objeto ou dicionário que você passou)
- `ApplicationName`, `ApplicationVersion`
- `MachineName`, `OsDescription`
- `IpAddress`, `CountryCode` (quando `EnableCountryLookup` está ativo)

A API espera **POST** no endpoint configurado, corpo **JSON** com um **array de eventos**.

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
