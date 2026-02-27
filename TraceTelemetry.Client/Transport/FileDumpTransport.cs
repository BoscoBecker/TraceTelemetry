using System;
using System.IO;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using TraceTelemetry.Client.Models;

namespace TraceTelemetry.Client.Transport
{
    /// <summary>
    /// Writes each batch to a file (NDJSON). Useful for POC or debugging when no API exists.
    /// </summary>
    public class FileDumpTransport : ITelemetryTransport
    {
        private readonly string _directoryPath;
        private readonly object _lock = new object();
        private static readonly JsonSerializerOptions JsonOptions = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, WriteIndented = false };

        public FileDumpTransport(string directoryPath)
        {
            _directoryPath = directoryPath ?? Path.GetTempPath();
            Directory.CreateDirectory(_directoryPath);
        }

        public Task<bool> SendBatchAsync(TelemetryEvent[] events, CancellationToken ct = default)
        {
            if (events == null || events.Length == 0)
                return Task.FromResult(true);
            try
            {
                lock (_lock)
                {
                    var file = Path.Combine(_directoryPath, $"telemetry-batch-{DateTime.UtcNow:yyyyMMdd-HHmmss}-{Guid.NewGuid():N}.ndjson");
                    using (var w = new StreamWriter(file, append: false))
                    {
                        foreach (var ev in events)
                            w.WriteLine(JsonSerializer.Serialize(ev, JsonOptions));
                    }
                }
                return Task.FromResult(true);
            }
            catch
            {
                return Task.FromResult(false);
            }
        }
    }
}
