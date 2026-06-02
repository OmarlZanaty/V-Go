using Microsoft.AspNetCore.Mvc;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.HTMLResponseService
{
    public interface IHtmlResponseService
    {
        ContentResult GenerateSuccessHtml(string userName);
        ContentResult GenerateErrorHtml(string title, string message);
        ContentResult GenerateInvalidStateHtml();
    }
}
