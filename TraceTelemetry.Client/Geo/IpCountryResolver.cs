using System;
using System.Collections.Concurrent;
using System.Net.Http;
using System.Text.Json;
using System.Threading;

namespace TraceTelemetry.Client.Geo
{
    /// <summary>
    /// Resolves country code from IP using a free geolocation API. Results are cached per IP.
    /// Uses a short timeout to avoid blocking; private/local IPs return empty string.
    /// </summary>
    public static class IpCountryResolver
    {
        private static readonly HttpClient _http = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(2),
            DefaultRequestHeaders = { { "User-Agent", "TraceTelemetry/1.0" } }
        };

        private static readonly ConcurrentDictionary<string, string> _cache = new ConcurrentDictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        private const string ApiUrl = "https://reallyfreegeoip.org/json/";

        /// <summary>
        /// Gets the two-letter country code for the given IP, or empty string if unknown/local/failed.
        /// Result is cached for subsequent calls.
        /// </summary>
        public static string GetCountryCode(string ip)
        {
            if (string.IsNullOrWhiteSpace(ip))
                return "";
            var trimmed = ip.Trim();
            if (IsPrivateOrLocal(trimmed))
                return "";

            if (_cache.TryGetValue(trimmed, out var cached))
                return cached ?? "";

            try
            {
                var cts = new CancellationTokenSource(TimeSpan.FromSeconds(2));
                var task = _http.GetStringAsync(ApiUrl + Uri.EscapeDataString(trimmed));
                if (!task.Wait(TimeSpan.FromSeconds(2)))
                    return "";
                var json = task.Result;
                var code = ParseCountryCode(json);
                _cache.TryAdd(trimmed, code ?? "");
                return code ?? "";
            }
            catch
            {
                _cache.TryAdd(trimmed, "");
                return "";
            }
        }

        private static bool IsPrivateOrLocal(string ip)
        {
            if (ip == "::1" || ip == "127.0.0.1" || ip.StartsWith("127."))
                return true;
            if (ip.StartsWith("10.") || ip.StartsWith("192.168.") || ip.StartsWith("172.16.") || ip.StartsWith("172.17.") || ip.StartsWith("172.18.") || ip.StartsWith("172.19.") ||
                ip.StartsWith("172.20.") || ip.StartsWith("172.21.") || ip.StartsWith("172.22.") || ip.StartsWith("172.23.") || ip.StartsWith("172.24.") || ip.StartsWith("172.25.") ||
                ip.StartsWith("172.26.") || ip.StartsWith("172.27.") || ip.StartsWith("172.28.") || ip.StartsWith("172.29.") || ip.StartsWith("172.30.") || ip.StartsWith("172.31."))
                return true;
            return false;
        }

        private static string ParseCountryCode(string json)
        {
            try
            {
                var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                if (root.TryGetProperty("country_code", out var cc))
                    return cc.GetString() ?? "";
                if (root.TryGetProperty("countryCode", out var cc2))
                    return cc2.GetString() ?? "";
            }
            catch { }
            return "";
        }
    }
}
