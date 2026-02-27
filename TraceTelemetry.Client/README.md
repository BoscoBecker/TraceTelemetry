# TraceTelemetry.Client

Pacote NuGet para telemetria **offline-first** em apps desktop (.NET Standard 2.0 / .NET 6+): fila NDJSON, envio em batch e timer automático. Thread-safe, sem dependências externas.

## Uso rápido

```csharp
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

var telemetry = new TelemetryClient(options);
telemetry.Start();

await telemetry.TrackAsync("order_created", new { OrderId = 123, Amount = 99.90m });
await telemetry.TrackAsync("screen_view", new { Screen = "Dashboard" });
await telemetry.TrackAsync("button_click", "ButtonName", "Save");
await telemetry.TrackAsync("app_start");

// Ao encerrar o app
telemetry.Stop();
```

## Overloads de `TrackAsync`

- `TrackAsync(string name)` — só o nome do evento
- `TrackAsync(string name, object data)` — evento + payload (objeto anônimo, etc.)
- `TrackAsync(string name, string propertyName, object propertyValue)` — uma propriedade
- `TrackAsync(string name, IReadOnlyDictionary<string, object> properties)` — dicionário de propriedades

## Comportamento

- **Offline-first**: eventos vão para um arquivo NDJSON (uma linha JSON por evento).
- **Batch**: o timer lê até `BatchSize` eventos e envia em uma única requisição HTTP.
- **Timer**: a cada `FlushIntervalSeconds` um flush automático é disparado.
- **Thread-safe**: enfileiramento e desenfileiramento são protegidos por lock.
- Sem API: deixe `EndpointUrl` vazio; os eventos continuam na fila. Use `FileDumpTransport` para gravar batches em arquivos (POC/debug).

## POC

Na pasta da solução, execute a POC que usa fila + `FileDumpTransport` (sem API):

```bash
dotnet run --project TraceTelemetry.Poc
```

Eventos e batches aparecem em `%TEMP%\TraceTelemetry.Poc\` (queue.ndjson e pasta batches).

## Gerar o pacote

```bash
dotnet pack TraceTelemetry.Client\TraceTelemetry.Client.csproj -c Release -o nupkgs
```

O `.nupkg` fica em `nupkgs\TraceTelemetry.Client.0.1.0-alpha.nupkg`.
