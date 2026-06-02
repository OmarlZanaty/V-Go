using Masafet_Elseka.Application.DTOs.Driver;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.Interfaces.IDriverService;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.DriverService
{
    public class DriverStatusSyncService : IHostedService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<DriverStatusSyncService> _logger;

        public DriverStatusSyncService(IServiceProvider serviceProvider, ILogger<DriverStatusSyncService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }

        public async Task StartAsync(CancellationToken cancellationToken)
        {
            using var scope = _serviceProvider.CreateScope();
            var driverService = scope.ServiceProvider.GetRequiredService<IDriverService>();
            var cacheService = scope.ServiceProvider.GetRequiredService<ICacheService>();

            try
            {
                var result = await driverService.GetAvailableDrivers();
                if (result is not null && result.IsSuccess && result.Data is not null)
                {
                    foreach (var driver in result.Data)
                    {
                        var status = new DriverStatusDTO
                        {
                            DriverId = driver.DriverId,
                            DriverName = driver.DriverName,
                            IsAvailable = driver.IsAvailable,
                        };

                        cacheService.SetData($"DriverStatus_{driver.DriverId}", status, TimeSpan.FromHours(1));
                    }

                    _logger.LogInformation("Driver statuses synced to cache.");
                }
                else
                {
                    _logger.LogWarning("No drivers were found to sync.");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error while syncing driver statuses.");
            }
        }

        public Task StopAsync(CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }
    }
}