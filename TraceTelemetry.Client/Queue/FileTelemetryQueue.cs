using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using TraceTelemetry.Client.Models;

namespace TraceTelemetry.Client.Queue
{
    public interface ITelemetryQueue
    {
        Task EnqueueAsync(TelemetryEvent evt, CancellationToken ct = default);
        /// <summary>Reads up to maxItems from the front without removing. Returns (batch, number of lines to remove).</summary>
        (IReadOnlyList<TelemetryEvent> batch, int linesToRemove) PeekBatch(int maxItems);
        /// <summary>Removes the first count lines from the queue. Call only after successful send.</summary>
        void RemoveFirst(int count);
        IReadOnlyList<TelemetryEvent> DequeueBatch(int maxItems);
        int PeekCount();
    }

    /// <summary>
    /// Thread-safe, NDJSON file-based queue for offline-first telemetry.
    /// One JSON object per line; append on enqueue, read/truncate on dequeue.
    /// </summary>
    public class FileTelemetryQueue : ITelemetryQueue
    {
        private readonly string _filePath;
        private readonly object _lock = new object();
        private static readonly JsonSerializerOptions JsonOptions = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            WriteIndented = false
        };

        public FileTelemetryQueue(TelemetryOptions options)
        {
            if (options == null)
                throw new ArgumentNullException(nameof(options));
            _filePath = string.IsNullOrWhiteSpace(options.QueuePath) ? "telemetry-queue.ndjson" : options.QueuePath.Trim();
            var dir = Path.GetDirectoryName(_filePath);
            if (!string.IsNullOrEmpty(dir))
                Directory.CreateDirectory(dir);
        }

        public Task EnqueueAsync(TelemetryEvent ev, CancellationToken ct = default)
        {
            if (ev == null)
                return Task.CompletedTask;
            try
            {
                lock (_lock)
                {
                    var line = JsonSerializer.Serialize(ev, JsonOptions) + Environment.NewLine;
                    File.AppendAllText(_filePath, line);
                }
            }
            catch
            {
                // leve: não propaga exceção; evento fica perdido mas app continua
            }
            return Task.CompletedTask;
        }

        /// <summary>Reads a batch without removing. Use RemoveFirst(linesToRemove) only after successful send. Never throws.</summary>
        public (IReadOnlyList<TelemetryEvent> batch, int linesToRemove) PeekBatch(int maxItems)
        {
            if (maxItems <= 0)
                return (Array.Empty<TelemetryEvent>(), 0);
            try
            {
                lock (_lock)
                {
                    if (!File.Exists(_filePath))
                        return (Array.Empty<TelemetryEvent>(), 0);

                    var allLines = File.ReadAllLines(_filePath);
                    if (allLines.Length == 0)
                        return (Array.Empty<TelemetryEvent>(), 0);

                    var take = Math.Min(maxItems, allLines.Length);
                    var batch = new List<TelemetryEvent>(take);

                    for (int i = 0; i < take; i++)
                    {
                        var line = allLines[i];
                        if (string.IsNullOrWhiteSpace(line))
                            continue;
                        try
                        {
                            var evt = JsonSerializer.Deserialize<TelemetryEvent>(line, JsonOptions);
                            if (evt != null)
                                batch.Add(evt);
                        }
                        catch { }
                    }

                    return (batch, take);
                }
            }
            catch
            {
                return (Array.Empty<TelemetryEvent>(), 0);
            }
        }

        /// <summary>Removes the first count lines. Call only after successful API send. Never throws.</summary>
        public void RemoveFirst(int count)
        {
            if (count <= 0)
                return;
            try
            {
                lock (_lock)
                {
                    if (!File.Exists(_filePath))
                        return;
                    var allLines = File.ReadAllLines(_filePath);
                    if (allLines.Length == 0)
                        return;
                    var toRemove = Math.Min(count, allLines.Length);
                    if (toRemove >= allLines.Length)
                    {
                        try { File.Delete(_filePath); } catch { }
                        return;
                    }
                    var remaining = new string[allLines.Length - toRemove];
                    Array.Copy(allLines, toRemove, remaining, 0, remaining.Length);
                    File.WriteAllLines(_filePath, remaining);
                }
            }
            catch
            {
                // queue unchanged; next flush will retry
            }
        }

        public IReadOnlyList<TelemetryEvent> DequeueBatch(int maxItems)
        {
            var (batch, linesToRemove) = PeekBatch(maxItems);
            if (linesToRemove > 0)
                RemoveFirst(linesToRemove);
            return batch;
        }

        public int PeekCount()
        {
            try
            {
                lock (_lock)
                {
                    if (!File.Exists(_filePath))
                        return 0;
                    var lines = File.ReadAllLines(_filePath);
                    return lines.Length;
                }
            }
            catch
            {
                return 0;
            }
        }
    }
}
