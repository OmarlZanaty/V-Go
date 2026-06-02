using Masafet_Elseka.Application.DTOs.Trip;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Hubs.HubHelper
{
    public interface IDriverNotifier
    {
        Task NotifyDriversOfNewTrip(TripOfferDTO offer, IEnumerable<string> driverIds);
    }
}
