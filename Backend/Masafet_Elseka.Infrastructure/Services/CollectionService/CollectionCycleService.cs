using Masafet_Elseka.Application.Interfaces.ICollectionService;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Masafet_Elseka.Infrastructure.Services.CollectionService
{
    // Drives the daily captain collection: evening notice, last-hour reminder, deadline
    // lock, and expiry of stale transfer requests. Ticks every minute; each phase is
    // claimed atomically in the database so restarts or extra instances never repeat it.
    public class CollectionCycleService : BackgroundService
    {
        private static readonly TimeSpan Interval = TimeSpan.FromMinutes(1);

        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<CollectionCycleService> _logger;

        public CollectionCycleService(IServiceProvider serviceProvider, ILogger<CollectionCycleService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            // Let startup migrations finish first.
            try { await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken); }
            catch (OperationCanceledException) { return; }

            using var timer = new PeriodicTimer(Interval);
            do
            {
                try
                {
                    using var scope = _serviceProvider.CreateScope();
                    await scope.ServiceProvider.GetRequiredService<ICollectionService>().RunCycleAsync();
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Collection cycle tick failed.");
                }
            }
            while (await timer.WaitForNextTickAsync(stoppingToken));
        }
    }
}
