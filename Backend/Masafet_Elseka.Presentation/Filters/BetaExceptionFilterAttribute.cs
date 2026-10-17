using Masafet_Elseka.Application.DTOs.Beta;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Masafet_Elseka.Presentation.Filters
{
    public sealed class BetaExceptionFilterAttribute : ExceptionFilterAttribute
    {
        public override void OnException(ExceptionContext context)
        {
            if (context.Exception is not BetaRequestException error) return;
            context.Result = new ObjectResult(new { message = error.Message }) { StatusCode = error.StatusCode };
            context.ExceptionHandled = true;
        }
    }
}
