using Masafet_Elseka.Application.Interfaces.IPaymentService;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.PaymentService
{
    // Edge case 5: voids Visa pre-auth holds that are still PreAuthSuccess past their
    // expiry window (createdAt + 6 days), so we never leave a customer's funds frozen
    // when a ride neither completed (capture) nor was cancelled (void). Runs every 6 hours.
    public class PreAuthExpiryService : BackgroundService
    {
        private static readonly TimeSpan Interval = TimeSpan.FromHours(6);

        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<PreAuthExpiryService> _logger;

        public PreAuthExpiryService(IServiceProvider serviceProvider, ILogger<PreAuthExpiryService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            using var timer = new PeriodicTimer(Interval);
            do
            {
                try
                {
                    using var scope = _serviceProvider.CreateScope();
                    var paymentService = scope.ServiceProvider.GetRequiredService<IPaymentService>();
                    var voided = await paymentService.VoidExpiredPreAuthsAsync();
                    if (voided > 0)
                    {
                        _logger.LogWarning("PreAuthExpiryService voided {Count} expired pre-auth hold(s).", voided);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "PreAuthExpiryService sweep failed.");
                }
            }
            while (await timer.WaitForNextTickAsync(stoppingToken));
        }
    }
}
