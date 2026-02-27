using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using TraceTelemetry.Client;
using TraceTelemetry.Client.Models;

namespace TraceTelemetry.Client.Transport
{
    public interface ITelemetryTransport
    {
        /// <summary>Sends batch to API. Never throws. Returns true if sent successfully, false otherwise (offline/error).</summary>
        Task<bool> SendBatchAsync(TelemetryEvent[] events, CancellationToken ct = default);
    }

    /// <summary>
    /// Sends telemetry batches to an HTTP endpoint. Creates its own HttpClient if none provided (zero external DI required).
    /// </summary>
    public class HttpTelemetryTransport : ITelemetryTransport
    {
        private readonly HttpClient _httpClient;
        private readonly TelemetryOptions _options;
        private readonly bool _ownsHttpClient;

        public HttpTelemetryTransport(TelemetryOptions options) : this(CreateDefaultClient(), options, ownsClient: true) { }

        public HttpTelemetryTransport(HttpClient httpClient, TelemetryOptions options)
            : this(httpClient ?? CreateDefaultClient(), options, ownsClient: httpClient == null) { }

        private HttpTelemetryTransport(HttpClient httpClient, TelemetryOptions options, bool ownsClient)
        {
            _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
            _options = options ?? throw new ArgumentNullException(nameof(options));
            _ownsHttpClient = ownsClient;
        }

        private static HttpClient CreateDefaultClient()
        {
            return new HttpClient();
        }

        public async Task<bool> SendBatchAsync(TelemetryEvent[] events, CancellationToken ct = default)
        {
            if (events == null || events.Length == 0)
                return true;
            if (string.IsNullOrWhiteSpace(_options.EndpointUrl))
                return true;

            try
            {
                var json = JsonSerializer.Serialize(events);
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                var request = new HttpRequestMessage(HttpMethod.Post, _options.EndpointUrl);
                request.Content = content;
                if (!string.IsNullOrEmpty(_options.ApiKey))
                    request.Headers.TryAddWithoutValidation("X-API-Key", _options.ApiKey);

                var response = await _httpClient.SendAsync(request, ct).ConfigureAwait(false);
                if (response.IsSuccessStatusCode)
                    return true;
                return false;
            }
            catch
            {
                return false;
            }
        }
    }
}
