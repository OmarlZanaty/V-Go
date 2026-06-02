using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Const
{
    public static class HubEvents
    {
        public const string ReceiveNewTrip = "ReceiveNewTrip";
        public const string ClientArrivedTrip = "ClientArrivedTrip";
        public const string DriverArrivedTrip = "DriverArrivedTrip";
        public const string TripStartedForClient = "TripStartedForClient";
        public const string TripStartedForDriver = "TripStartedForDriver";
        public const string TripEndedForClient = "TripEndedForClient";
        public const string TripEndedForDriver = "TripEndedForDriver";
        public const string TripRejected = "TripRejected";
        public const string TripApprovedForClient = "TripApprovedForClient";
        public const string TripApprovedForAdmin = "TripApprovedForAdmin";
        public const string TripCancelledForAdmin = "TripCancelledForAdmin";
        public const string TripCancelledByClient = "TripCancelledByClient";
        public const string TripCancelledForClient = "TripCancelledForClient";
        public const string RecievePendingTrips = "RecievePendingTrips";
        public const string ReceiveCurrentTrip = "ReceiveCurrentTrip";
        public const string ReceiveCurrentTripError = "ReceiveCurrentTripError";
        public const string TripCancelledForTripDriver = "TripCancelledForTripDriver";
        public const string TripTakenByAnotherDriver = "TripTakenByAnotherDriver";
        public const string TripPaymentUpdated = "TripPaymentUpdated";

    }
}
