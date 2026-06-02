using Masafet_Elseka.Application.DTOs.Trip;
using Microsoft.AspNetCore.SignalR;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Hubs.HubHelper
{
    public class DriverNotifier: IDriverNotifier
    {

        private readonly IHubContext<DriverHub> _driverHubContext;

        public DriverNotifier(IHubContext<DriverHub> driverHubContext)
        {
            _driverHubContext = driverHubContext;
        }

        public async Task NotifyDriversOfNewTrip(TripOfferDTO offer, IEnumerable<string> driverIds)
        {
            foreach (var driverId in driverIds)
            {
                await _driverHubContext.Clients.Group($"Driver_{driverId}")
                    .SendAsync("NewTripRequested", offer);
            }
        }
    }
}
