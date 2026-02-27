using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using TraceTelemetry.Client.Geo;
using TraceTelemetry.Client.Models;
using TraceTelemetry.Client.Queue;
using TraceTelemetry.Client.Transport;

namespace TraceTelemetry.Client
{
    /// <summary>
    /// Offline-first telemetry client: enqueues to NDJSON file, flushes in batches on a timer. Thread-safe.
    /// </summary>
    public class TelemetryClient
    {
        private readonly TelemetryOptions _options;
        private readonly ITelemetryQueue _queue;
        private readonly ITelemetryTransport _transport;
        private readonly object _flushLock = new object();
        private Timer _timer;
        private bool _started;
        private bool _disposed;

        public TelemetryClient(TelemetryOptions options)
            : this(options, null, null) { }

        public TelemetryClient(TelemetryOptions options, ITelemetryQueue queue, ITelemetryTransport transport)
        {
            _options = options ?? throw new ArgumentNullException(nameof(options));
            _queue = queue ?? new FileTelemetryQueue(options);
            _transport = transport ?? new HttpTelemetryTransport(options);
        }

        /// <summary>
        /// Starts the automatic flush timer. Call once after creating the client.
        /// </summary>
        public void Start()
        {
            if (_started || _disposed)
                return;
            _started = true;
            var intervalMs = Math.Max(1000, _options.FlushIntervalSeconds) * 1000;
            _timer = new Timer(OnTimerTick, null, intervalMs, intervalMs);
        }

        /// <summary>
        /// Stops the timer and optionally flushes remaining events. Disposes the client.
        /// </summary>
        public void Stop()
        {
            _started = false;
            _disposed = true;
            _timer?.Change(Timeout.Infinite, Timeout.Infinite);
            _timer?.Dispose();
            _timer = null;
        }

        private void OnTimerTick(object state)
        {
            if (Monitor.TryEnter(_flushLock))
            {
                try
                {
                    FlushAsync().GetAwaiter().GetResult();
                }
                catch
                {
                    // avoid killing the timer thread; events stay in queue for next flush
                }
                finally
                {
                    Monitor.Exit(_flushLock);
                }
            }
        }

        /// <summary>
        /// Tries to send one batch to the API. Removes from queue only on success (internet/API OK). Never throws.
        /// </summary>
        public async Task FlushAsync(CancellationToken ct = default)
        {
            var (batch, linesToRemove) = _queue.PeekBatch(_options.BatchSize);
            if (batch == null || batch.Count == 0 || linesToRemove <= 0)
                return;
            var array = new TelemetryEvent[batch.Count];
            for (int i = 0; i < batch.Count; i++)
                array[i] = batch[i];
            bool sent = false;
            try
            {
                sent = await _transport.SendBatchAsync(array, ct).ConfigureAwait(false);
            }
            catch
            {
                // transport already swallows; extra guard
            }
            if (sent && linesToRemove > 0)
                _queue.RemoveFirst(linesToRemove);
        }

        /// <summary>
        /// Tracks an event by name. Thread-safe, offline-first (writes to NDJSON queue).
        /// </summary>
        public Task TrackAsync(string name, CancellationToken ct = default)
        {
            return TrackAsync(name, (object)null, ct);
        }

        /// <summary>
        /// Tracks an event with optional payload (e.g. anonymous object or dictionary).
        /// </summary>
        public Task TrackAsync(string name, object data, CancellationToken ct = default)
        {
            try
            {
                var ev = BuildEvent(name ?? string.Empty, data);
                return _queue.EnqueueAsync(ev, ct);
            }
            catch
            {
                return Task.CompletedTask;
            }
        }

        /// <summary>
        /// Tracks an event with a single property (convenience overload).
        /// </summary>
        public Task TrackAsync(string name, string propertyName, object propertyValue, CancellationToken ct = default)
        {
            var data = propertyName == null ? (object)null : new Dictionary<string, object> { { propertyName, propertyValue } };
            return TrackAsync(name, data, ct);
        }

        /// <summary>
        /// Tracks an event with key-value properties.
        /// </summary>
        public Task TrackAsync(string name, IReadOnlyDictionary<string, object> properties, CancellationToken ct = default)
        {
            return TrackAsync(name, (object)properties, ct);
        }

        /// <summary>
        /// Tracks an exception with message, stack trace and type. Never throws.
        /// </summary>
        public Task TrackExceptionAsync(Exception ex, string eventName = "exception", object extraData = null, CancellationToken ct = default)
        {
            if (ex == null)
                return Task.CompletedTask;
            try
            {
                var data = new Dictionary<string, object>
                {
                    ["message"] = ex.Message ?? "",
                    ["stackTrace"] = ex.StackTrace ?? "",
                    ["exceptionType"] = ex.GetType().FullName ?? ""
                };
                if (ex.InnerException != null)
                    data["innerMessage"] = ex.InnerException.Message ?? "";
                if (extraData != null)
                {
                    if (extraData is IDictionary<string, object> dict)
                    {
                        foreach (var kv in dict)
                            data[kv.Key] = kv.Value;
                    }
                    else
                        data["extra"] = extraData;
                }
                var ev = BuildEvent(eventName, data);
                return _queue.EnqueueAsync(ev, ct);
            }
            catch
            {
                return Task.CompletedTask;
            }
        }

        private TelemetryEvent BuildEvent(string name, object data)
        {
            var ip = GetLocalIpAddress();
            return new TelemetryEvent
            {
                Name = name,
                TimestampUtc = DateTime.UtcNow,
                Data = data,
                ApplicationName = _options?.ApplicationName ?? string.Empty,
                ApplicationVersion = _options?.ApplicationVersion ?? string.Empty,
                MachineName = GetMachineName(),
                OsDescription = GetOsDescription(),
                IpAddress = ip,
                CountryCode = _options.EnableCountryLookup ? IpCountryResolver.GetCountryCode(ip) : string.Empty
            };
        }

        private static string GetMachineName()
        {
            try { return Environment.MachineName ?? ""; }
            catch { return ""; }
        }

        private static string GetOsDescription()
        {
            try { return RuntimeInformation.OSDescription ?? ""; }
            catch { return ""; }
        }

        private static string GetLocalIpAddress()
        {
            try
            {
                var host = Dns.GetHostEntry(Dns.GetHostName());
                foreach (var addr in host.AddressList)
                {
                    if (addr.AddressFamily == AddressFamily.InterNetwork)
                        return addr.ToString();
                }
                if (host.AddressList != null && host.AddressList.Length > 0)
                    return host.AddressList[0].ToString();
            }
            catch { }
            return "";
        }

        /// <summary>
        /// Current number of events in the queue (approximate, for diagnostics).
        /// </summary>
        public int QueuedCount => _queue.PeekCount();
    }
}
