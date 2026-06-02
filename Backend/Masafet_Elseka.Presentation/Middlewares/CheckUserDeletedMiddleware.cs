using Masafet_Elseka.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Masafet_Elseka.Presentation.Middlewares
{
    public class CheckUserDeletedMiddleware
    {
        private readonly RequestDelegate _next;

        public CheckUserDeletedMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            if (TryGetUserIdFromRoute(context, out var userId))
            {
                if (string.IsNullOrWhiteSpace(userId))
                {
                    context.Response.StatusCode = StatusCodes.Status400BadRequest;
                    await context.Response.WriteAsJsonAsync(new { message = "Invalid user id." });
                    return;
                }

                var db = context.RequestServices.GetRequiredService<Context>();

                var user = await db.Users
                                   .IgnoreQueryFilters() 
                                   .FirstOrDefaultAsync(x => x.Id == userId);

                if (user == null || user.IsDeleted)
                {
                    context.Response.StatusCode = StatusCodes.Status404NotFound;
                    await context.Response.WriteAsJsonAsync(new { message = "User not found" });
                    return;
                }
            }

            await _next(context);
        }

        private bool TryGetUserIdFromRoute(HttpContext context, out string? userId)
        {
            // أكثر أسماء مستخدمة للـUser Id
            var keys = new[] { "userId", "UserId", "userid", "id" };

            foreach (var key in keys)
            {
                if (context.Request.RouteValues.TryGetValue(key, out var value) && value != null)
                {
                    userId = value.ToString();
                    return true;
                }
            }

            userId = null;
            return false;
        }
    }
}
