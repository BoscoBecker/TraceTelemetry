using System;
using System.Text.Json;

namespace TraceTelemetry.Client.Models
{
    public class TelemetryEvent
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N");
        public string Name { get; set; } = string.Empty;
        public DateTime TimestampUtc { get; set; } = DateTime.UtcNow;
        public object Data { get; set; }
        public string ApplicationName { get; set; } = string.Empty;
        public string ApplicationVersion { get; set; } = string.Empty;
        /// <summary>Machine name (Environment.MachineName).</summary>
        public string MachineName { get; set; } = string.Empty;
        /// <summary>OS description (RuntimeInformation.OSDescription).</summary>
        public string OsDescription { get; set; } = string.Empty;
        /// <summary>Local IP address (resolved once at first use).</summary>
        public string IpAddress { get; set; } = string.Empty;
        /// <summary>Country code (e.g. BR, US) from IP geolocation when available.</summary>
        public string CountryCode { get; set; } = string.Empty;

        public static TelemetryEvent Create(string name, object data = null)
        {
            return new TelemetryEvent
            {
                Name = name,
                Data = data
            };
        }

        public string ToJson()
        {
            return JsonSerializer.Serialize(this);
        }
    }
}