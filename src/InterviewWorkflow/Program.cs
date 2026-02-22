using Microsoft.Extensions.Hosting;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.Extensibility;

namespace InterviewWorkflow
{
    public class Program
    {
        public static async Task Main(string[] args)
        {
            var host = new HostBuilder()
                .ConfigureFunctionsWorkerDefaults()
                .ConfigureServices((context, services) =>
                {
                    services.AddApplicationInsightsTelemetryWorkerService(options =>
                    {
                        options.ConnectionString = Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING");
                        options.EnableAdaptiveSampling = true;
                    });

                    services.Configure<TelemetryConfiguration>(config =>
                    {
                        config.TelemetryInitializers.Add(new InterviewTelemetryInitializer());
                    });

                    services.AddSingleton<ITelemetryService, TelemetryService>();
                })
                .ConfigureLogging(logging =>
                {
                    logging.AddApplicationInsights();
                    logging.SetMinimumLevel(LogLevel.Information);
                })
                .Build();

            await host.RunAsync();
        }
    }

    public class InterviewTelemetryInitializer : ITelemetryInitializer
    {
        public void Initialize(ITelemetry telemetry)
        {
            if (telemetry == null) return;
            
            telemetry.Context.Cloud.RoleName = "InterviewSystem-India";
            telemetry.Context.GlobalProperties["Environment"] = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production";
            telemetry.Context.GlobalProperties["Region"] = Environment.GetEnvironmentVariable("REGION") ?? "centralindia";
            telemetry.Context.GlobalProperties["Country"] = "India";
        }
    }

    public interface ITelemetryService
    {
        void TrackInterviewStarted(string interviewId, string candidateEmail);
        void TrackInterviewCompleted(string interviewId, string outcome, int score);
        void TrackEvent(string eventName, Dictionary<string, string>? properties = null);
        void TrackException(Exception ex, Dictionary<string, string>? properties = null);
    }

    public class TelemetryService : ITelemetryService
    {
        private readonly TelemetryClient _telemetryClient;
        private readonly ILogger<TelemetryService> _logger;

        public TelemetryService(TelemetryClient telemetryClient, ILogger<TelemetryService> logger)
        {
            _telemetryClient = telemetryClient;
            _logger = logger;
        }

        public void TrackInterviewStarted(string interviewId, string candidateEmail)
        {
            var properties = new Dictionary<string, string>
            {
                ["InterviewId"] = interviewId,
                ["CandidateEmail"] = candidateEmail,
                ["EventType"] = "InterviewStarted",
                ["Region"] = "India"
            };

            _telemetryClient?.TrackEvent("InterviewStarted", properties);
            _logger.LogInformation("Interview started in India: {InterviewId} for {CandidateEmail}", interviewId, candidateEmail);
        }

        public void TrackInterviewCompleted(string interviewId, string outcome, int score)
        {
            var properties = new Dictionary<string, string>
            {
                ["InterviewId"] = interviewId,
                ["Outcome"] = outcome,
                ["Score"] = score.ToString(),
                ["EventType"] = "InterviewCompleted",
                ["Region"] = "India"
            };

            _telemetryClient?.TrackEvent("InterviewCompleted", properties);
            _telemetryClient?.TrackMetric("InterviewScore", score, properties);
        }

        public void TrackEvent(string eventName, Dictionary<string, string>? properties = null)
        {
            _telemetryClient?.TrackEvent(eventName, properties);
        }

        public void TrackException(Exception ex, Dictionary<string, string>? properties = null)
        {
            _telemetryClient?.TrackException(ex, properties);
            _logger.LogError(ex, "Exception tracked in India region: {Message}", ex.Message);
        }
    }
}