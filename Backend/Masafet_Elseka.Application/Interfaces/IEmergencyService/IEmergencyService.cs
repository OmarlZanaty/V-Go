using Masafet_Elseka.Application.DTOs.Driver;
using Masafet_Elseka.Application.Response;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.IEmergencyService
{
    public interface IEmergencyService
    {
        Task <Response<DriverAlertDataDTO>> SendAlert(AlertDTO model);
    }
}
