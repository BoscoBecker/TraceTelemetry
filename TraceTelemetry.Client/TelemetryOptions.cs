namespace TraceTelemetry.Client
{
    public class TelemetryOptions
    {
        public string EndpointUrl { get; set; } = string.Empty;
        public string ApiKey { get; set; } = string.Empty;
        public string QueuePath { get; set; } = "telemetry-queue.ndjson";
        public int BatchSize { get; set; } = 20;
        public int FlushIntervalSeconds { get; set; } = 10;
        /// <summary>Optional. Sent with every event for filtering in the API.</summary>
        public string ApplicationName { get; set; } = string.Empty;
        /// <summary>Optional. e.g. "1.0.0"</summary>
        public string ApplicationVersion { get; set; } = string.Empty;
        /// <summary>When true (default), resolve country code from IP using a free geolocation API (cached per IP).</summary>
        public bool EnableCountryLookup { get; set; } = true;
    }
}