using System.Security.Cryptography;
using System.Text;
using Masafet_Elseka.Infrastructure.Services.BetaService;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Masafet_Elseka.Presentation.Filters
{
    // Authorization filters run before model binding/automatic 400 responses.
    [AttributeUsage(AttributeTargets.Method)]
    public sealed class BetaSyncKeyAttribute : Attribute, IAuthorizationFilter
    {
        public void OnAuthorization(AuthorizationFilterContext context)
        {
            var expected = context.HttpContext.RequestServices.GetRequiredService<BetaOptions>().SyncKey;
            var supplied = context.HttpContext.Request.Headers["X-Sync-Key"];
            if (string.IsNullOrWhiteSpace(expected) || supplied.Count != 1 || string.IsNullOrEmpty(supplied[0])
                || !CryptographicOperations.FixedTimeEquals(
                    SHA256.HashData(Encoding.UTF8.GetBytes(expected)),
                    SHA256.HashData(Encoding.UTF8.GetBytes(supplied[0]!))))
                context.Result = new NotFoundResult();
        }
    }
}
