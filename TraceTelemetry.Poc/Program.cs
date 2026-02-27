using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using TraceTelemetry.Client;

namespace TraceTelemetry.Poc
{
    /// <summary>
    /// POC: client envia para a API (POST /telemetry). API persiste em SQLite.
    /// Suba a API antes: dotnet run --project TraceTelemetry.API\API.CollectTelemetry
    /// Config em appsettings.json: RunLoop = true para enviar em loop a cada LoopIntervalSeconds.
    /// </summary>
    internal static class Program
    {
        static async Task Main(string[] args)
        {
            var config = new ConfigurationBuilder()
                .SetBasePath(AppContext.BaseDirectory)
                .AddJsonFile("appsettings.json", optional: true, reloadOnChange: false)
                .Build();

            var runLoop = config.GetValue<bool>("Telemetry:RunLoop");
            var loopIntervalSeconds = Math.Max(1, config.GetValue<int>("Telemetry:LoopIntervalSeconds"));
            var apiBase = config["Telemetry:ApiBaseUrl"] ?? Environment.GetEnvironmentVariable("TELEMETRY_API_URL") ?? "https://boscobecker.fun/";
            var endpointUrl = apiBase.TrimEnd('/') + "/telemetry";

            var baseDir = Path.Combine(Path.GetTempPath(), "TraceTelemetry.Poc");
            Directory.CreateDirectory(baseDir);

            var options = new TelemetryOptions
            {
                EndpointUrl = endpointUrl,
                ApiKey = config["Telemetry:ApiKey"] ?? "",
                QueuePath = Path.Combine(baseDir, "queue.ndjson"),
                BatchSize = Math.Max(1, config.GetValue<int>("Telemetry:BatchSize")),
                FlushIntervalSeconds = Math.Max(1, config.GetValue<int>("Telemetry:FlushIntervalSeconds")),
                ApplicationName = config["Telemetry:ApplicationName"] ?? "PocApp",
                ApplicationVersion = config["Telemetry:ApplicationVersion"] ?? "1.0.0"
            };

            var telemetry = new TelemetryClient(options);
            telemetry.Start();

            Console.WriteLine("Telemetry started. API: " + endpointUrl);
            Console.WriteLine("Queue: " + options.QueuePath);
            Console.WriteLine("RunLoop: " + runLoop + (runLoop ? " (interval: " + loopIntervalSeconds + "s)" : ""));

            if (runLoop)
            {
                Console.WriteLine("Enviando lotes a cada " + loopIntervalSeconds + "s. Ctrl+C para parar.");
                var cts = new CancellationTokenSource();
                Console.CancelKeyPress += (_, e) => { e.Cancel = true; cts.Cancel(); };

                int round = 0;
                while (!cts.Token.IsCancellationRequested)
                {
                    round++;
                    // Lote: vários eventos por rodada
                    await telemetry.TrackAsync("poc_loop", new { Round = round, At = DateTime.UtcNow });
                    await telemetry.TrackAsync("order_created", new { OrderId = 1000 + round, Amount = 10.0m * round });
                    await telemetry.TrackAsync("screen_view", new { Screen = "Loop", Round = round });
                    await telemetry.TrackAsync("app_heartbeat", new { telemetry.QueuedCount });

                    await telemetry.FlushAsync(cts.Token);
                    Console.WriteLine("[{0:HH:mm:ss}] Round {1} enviado. QueuedCount = {2}", DateTime.Now, round, telemetry.QueuedCount);

                    try
                    {
                        await Task.Delay(TimeSpan.FromSeconds(loopIntervalSeconds), cts.Token);
                    }
                    catch (OperationCanceledException)
                    {
                        break;
                    }
                }
                telemetry.Stop();
                Console.WriteLine("Loop encerrado.");
                return;
            }

            // Modo one-shot (RunLoop = false)
            await telemetry.TrackAsync("machine_info", new { CollectedAt = DateTime.UtcNow });
            await telemetry.TrackAsync("order_created", new { OrderId = 123, Amount = 99.90m });
            await telemetry.TrackAsync("order_created", new { OrderId = 124 });
            await telemetry.TrackAsync("screen_view", new { Screen = "Dashboard" });
            await telemetry.TrackAsync("button_click", "ButtonName", "Save");
            await telemetry.TrackAsync("app_start");

            try
            {
                throw new InvalidOperationException("Simulated POC exception for dashboard testing.");
            }
            catch (Exception ex)
            {
                await telemetry.TrackExceptionAsync(ex, "exception", new { Source = "PocApp", Simulated = true });
                Console.WriteLine("Exception tracked (stacktrace in dashboard).");
            }

            Console.WriteLine("Queued 7 events. QueuedCount = " + telemetry.QueuedCount);
            await Task.Delay(TimeSpan.FromSeconds(4));
            await telemetry.FlushAsync();
            Console.WriteLine("After first flush, QueuedCount = " + telemetry.QueuedCount);

            await telemetry.TrackAsync("order_created", new { OrderId = 125 });
            await Task.Delay(TimeSpan.FromSeconds(4));
            telemetry.Stop();
            Console.WriteLine("Stopped.");
        }
    }
}
