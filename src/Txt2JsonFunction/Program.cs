using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.Extensions.Logging;
using Txt2JsonFunction.Services;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices(services =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();
        
        // Register custom services
        services.AddScoped<AuthenticationService>();
        services.AddScoped<FileProcessingService>();
        
        // Configure logging
        services.Configure<LoggerFilterOptions>(options =>
        {
            // Ensure Application Insights logs are not filtered out
            LoggerFilterRule toRemove = options.Rules.FirstOrDefault(rule => rule.ProviderName
                == "Microsoft.Extensions.Logging.ApplicationInsights.ApplicationInsightsLoggerProvider");
            if (toRemove is not null)
            {
                options.Rules.Remove(toRemove);
            }
        });
    })
    .Build();

host.Run();
