using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Enums
{
    public enum TripStatus
    {
        Pending = 1, // when user request a trip
        Accepted = 2, // when driver accept the trip
        Arrived = 3, // when driver arrive to location of trip
        InProgress = 4, // when driver is on way with client to location of trip
        Completed = 5, // when deiver end trip and user confirm it
        Canceled = 6, // when user or driver cancel the trip
        Rejected = 7, // when driver reject the trip

    }

}
