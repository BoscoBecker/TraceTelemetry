# TraceTelemetry SDK for Delphi

SDK Delphi para telemetria offline-first com fila NDJSON e envio em lote via HTTP. Compatível com as versões .NET e Python do TraceTelemetry.

## Características

- **Offline-first**: Eventos são gravados em fila NDJSON local antes do envio
- **Thread-safe**: Pode ser usado em aplicações multithread
- **Envio em lote**: Configurável para otimizar uso de banda
- **Timer automático**: Flush periódico sem intervenção manual
- **Compatível**: Mesma API surface que as versões .NET e Python
- **Leve**: Mínimas dependências externas

## Instalação

1. Compile o pacote `TraceTelemetry.Delphi.dproj`
2. Adicione o caminho `Source` ao seu projeto Delphi
3. Adicione as units necessárias ao uses clause

## Uso Básico

```delphi
uses
  TraceTelemetry.Client, TraceTelemetry.Options;

var
  Options: TTelemetryOptions;
  Client: TTelemetryClient;
begin
  // Configurar opções
  Options := TTelemetryOptions.Create;
  try
    Options.EndpointUrl := 'https://boscobecker.fun/telemetry';
    Options.ApiKey := 'sua-chave-api';
    Options.ApplicationName := 'MinhaApp';
    Options.ApplicationVersion := '1.0.0';
    
    // Criar cliente
    Client := TTelemetryClient.Create(Options);
    try
      Client.Start;
      
      // Rastrear eventos
      Client.Track('app_start');
      Client.Track('button_click', 'button_name', 'Save');
      Client.Track('order_created', TJSONObject.ParseJSONValue('{"order_id": 123, "amount": 99.90}') as TJSONObject);
      
      // Rastrear exceção
      try
        // código que pode lançar exceção
      except
        on E: Exception do
          Client.TrackException(E, 'exception');
      end;
      
      // Forçar envio (opcional, timer automático cuida disso)
      Client.Flush;
      
    finally
      Client.Stop;
      Client.Free;
    end;
    
  finally
    Options.Free;
  end;
end;
```

## Configuração

### TTelemetryOptions

| Propriedade | Tipo | Default | Descrição |
|-------------|------|---------|-----------|
| `EndpointUrl` | string | `https://boscobecker.fun/telemetry` | URL da API de telemetria |
| `ApiKey` | string | `''` | Chave de API (opcional) |
| `QueuePath` | string | Temp dir | Caminho do arquivo de fila NDJSON |
| `BatchSize` | Integer | `5` | Eventos por lote |
| `FlushIntervalSeconds` | Integer | `3` | Intervalo do timer de flush |
| `ApplicationName` | string | `''` | Nome da aplicação |
| `ApplicationVersion` | string | `''` | Versão da aplicação |
| `EnableCountryLookup` | Boolean | `False` | Habilita lookup de país por IP |

## API Reference

### TTelemetryClient

#### Métodos

- `Start`: Inicia o timer de flush automático
- `Stop`: Para o timer e limpa recursos
- `Flush`: Envia um lote para a API (thread-safe)
- `Track(name)`: Rastreia evento simples
- `Track(name, data)`: Rastreia evento com payload JSON
- `Track(name, propertyName, propertyValue)`: Rastreia evento com uma propriedade
- `TrackException(exception, eventName, extraData)`: Rastreia exceção

#### Propriedades

- `QueuedCount`: Número de eventos na fila (aproximado)

## Exemplo POC

Veja a pasta `Examples` para um exemplo completo (POC) que demonstra:

- Configuração via variáveis de ambiente
- Modo one-shot e modo loop
- Diversos tipos de eventos
- Tratamento de exceções
- Monitoramento da fila

### Executando o POC

```bash
# Compilar
cd Examples
msbuild Poc.dproj /p:Configuration=Release

# Executar (modo one-shot)
Poc.exe

# Executar (modo loop)
set RUN_LOOP=true
set LOOP_INTERVAL=5
Poc.exe
```

### Variáveis de Ambiente

| Variável | Default | Descrição |
|----------|---------|-----------|
| `TELEMETRY_API_URL` | `https://boscobecker.fun/` | Base da API |
| `TELEMETRY_API_KEY` | `''` | Chave X-API-Key |
| `RUN_LOOP` | `false` | Envia lotes em loop |
| `LOOP_INTERVAL` | `5` | Segundos entre rodadas |
| `BATCH_SIZE` | `5` | Eventos por lote |
| `FLUSH_INTERVAL` | `3` | Segundos do timer |

## Arquitetura

O SDK segue a mesma arquitetura das versões .NET e Python:

1. **TelemetryClient**: Interface principal, thread-safe
2. **TelemetryOptions**: Configuração centralizada
3. **TelemetryEvent**: Modelo de dados do evento
4. **ITelemetryQueue**: Interface de fila (implementação NDJSON)
5. **ITelemetryTransport**: Interface de transporte (implementação HTTP)

## Compatibilidade

- Delphi 10.4+ (testado em 10.4, 11.0, 12.0)
- Windows 32/64 bit
- Requer units: System.JSON, System.Net.HttpClient, System.Classes

## Licença

MIT License - mesmo licenciamento dos projetos relacionados.
