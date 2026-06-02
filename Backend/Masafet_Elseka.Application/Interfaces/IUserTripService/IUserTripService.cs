using Masafet_Elseka.Application.DTOs.UserTripDTO;
using Masafet_Elseka.Application.Response;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.IUserTripService
{
    public interface IUserTripService
    {
        public  Task<Response<string>> AssignUserToTrip(UserTripDTO model);
    }
}
