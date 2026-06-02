using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Const
{
    public static class HubGroups
    {
        public const string Admin = "Admin";
        public const string Drivers = "Drivers";

        public static string User(string userId) => $"User_{userId}";
        public static string Driver(string driverId) => $"Driver_{driverId}";
    }
}
