using System.Security.Claims;
using Masafet_Elseka.Application.Helpers;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Masafet_Elseka.Presentation.Middlewares
{
    // A blocked account is cut off on its next request (REST or a hub connect), not
    // only at its next login: the apps see ACCOUNT_BLOCKED and sign out.
    public class BlockedUserMiddleware
    {
        public const string Code = "ACCOUNT_BLOCKED";
        public const string Message = "حسابك موقوف، تواصل مع الدعم";

        private readonly RequestDelegate _next;

        public BlockedUserMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (!string.IsNullOrEmpty(userId) && !context.User.IsInRole("Admin") && !context.User.IsInRole("Dispatcher"))
            {
                if (!BlockedUserCache.TryGet(userId, out var blocked))
                {
                    var db = context.RequestServices.GetRequiredService<Context>();
                    blocked = await db.Users.AsNoTracking().AnyAsync(u => u.Id == userId && u.IsBlocked);
                    BlockedUserCache.Set(userId, blocked);
                }
                if (blocked)
                {
                    context.Response.StatusCode = StatusCodes.Status403Forbidden;
                    await context.Response.WriteAsJsonAsync(new { isSuccess = false, code = Code, message = Message, statusCode = 403 });
                    return;
                }
            }

            await _next(context);
        }
    }
}
