using Masafet_Elseka.Application.DTOs;
using Masafet_Elseka.Application.Response;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.ExternalInterfaces
{
    public interface IMailService
    {
        public Task<Response<bool>> SendEmailAsync(MailRequestDTO mailRequest);
    }
}
