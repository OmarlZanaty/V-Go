using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Masafet_Elseka.Application.Interfaces.IBetaService;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.Services.BetaService;
using Masafet_Elseka.Presentation.Controllers;
using Masafet_Elseka.Presentation.Middlewares;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Masafet_Elseka.Tests
{
    public class BetaEndpointTests
    {
        private static TestServer Server(string? key)
        {
            var database = Guid.NewGuid().ToString();
            return new TestServer(new WebHostBuilder().ConfigureServices(services =>
            {
                services.AddLogging();
                services.AddDbContext<Context>(o => o.UseInMemoryDatabase(database));
                services.AddSingleton(new BetaOptions { SyncKey = key });
                services.AddSingleton<TimeProvider>(new BetaServiceTests.TestClock());
                services.AddScoped<IBetaGoogleTokenVerifier, BetaServiceTests.FakeGoogle>();
                services.AddScoped<IBetaService, BetaService>();
                services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
                services.AddAuthorization();
                services.AddControllers().AddApplicationPart(typeof(BetaController).Assembly);
                services.AddRateLimiter(options =>
                {
                    options.RejectionStatusCode = 429;
                    options.AddFixedWindowLimiter("beta-enroll", limiter =>
                    {
                        limiter.PermitLimit = 10;
                        limiter.Window = TimeSpan.FromMinutes(1);
                        limiter.QueueLimit = 0;
                    });
                });
            }).Configure(app =>
            {
                app.UseRouting();
                app.UseRateLimiter();
                app.UseAuthentication();
                app.UseMiddleware<BlockedUserMiddleware>();
                app.UseAuthorization();
                app.UseEndpoints(endpoints => endpoints.MapControllers());
            }));
        }

        [Theory]
        [InlineData(null, null)]
        [InlineData(null, "test-key")]
        [InlineData("", "test-key")]
        [InlineData("test-key", null)]
        [InlineData("test-key", "wrong")]
        [InlineData("test-key", "same-len")]
        public async Task Missing_or_wrong_sync_key_returns_404_even_before_body_validation(string? configured, string? supplied)
        {
            using var server = Server(configured);
            using var client = server.CreateClient();
            if (supplied != null) client.DefaultRequestHeaders.Add("X-Sync-Key", supplied);
            Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/api/beta/sync/pending")).StatusCode);
            foreach (var route in new[] { "done", "failed" })
            {
                using var malformed = new StringContent("{", Encoding.UTF8, "application/json");
                Assert.Equal(HttpStatusCode.NotFound, (await client.PostAsync($"/api/beta/sync/{route}", malformed)).StatusCode);
            }
        }

        [Fact]
        public async Task Public_enrollment_and_daemon_round_trip_match_json_contract()
        {
            using var server = Server("test-key");
            using var client = server.CreateClient();
            var enrolled = await client.PostAsJsonAsync("/api/beta/enroll", new { email = " Person@gmail.com ", app = "captain" });
            Assert.Equal(HttpStatusCode.OK, enrolled.StatusCode);
            using var enrollJson = JsonDocument.Parse(await enrolled.Content.ReadAsStringAsync());
            Assert.Equal(new[] { "alreadyEnrolled", "delayed", "downloadUrl", "playSynced", "playUrl", "status" },
                enrollJson.RootElement.EnumerateObject().Select(p => p.Name).OrderBy(n => n).ToArray());
            client.DefaultRequestHeaders.Add("X-Sync-Key", "test-key");
            var pending = await client.GetAsync("/api/beta/sync/pending");
            Assert.Equal(HttpStatusCode.OK, pending.StatusCode);
            using var pendingJson = JsonDocument.Parse(await pending.Content.ReadAsStringAsync());
            var tester = pendingJson.RootElement.GetProperty("testers")[0];
            Assert.Equal(JsonValueKind.String, tester.GetProperty("id").ValueKind);
            Assert.Equal("person@gmail.com", tester.GetProperty("email").GetString());
            var done = await client.PostAsJsonAsync("/api/beta/sync/done", new { ids = new[] { tester.GetProperty("id").GetString() } });
            Assert.Equal(HttpStatusCode.OK, done.StatusCode);
            using var statusJson = JsonDocument.Parse(await client.GetStringAsync("/api/beta/enroll/status?email=person@gmail.com"));
            Assert.Equal(new[] { "delayed", "registered", "rejected", "synced" },
                statusJson.RootElement.EnumerateObject().Select(p => p.Name).OrderBy(n => n).ToArray());
            Assert.True(statusJson.RootElement.GetProperty("synced").GetBoolean());
            Assert.False(statusJson.RootElement.GetProperty("delayed").GetBoolean());
        }

        [Fact]
        public async Task Enrollment_is_rate_limited()
        {
            using var server = Server("test-key");
            using var client = server.CreateClient();
            for (var i = 0; i < 10; i++)
                Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync("/api/beta/enroll", new { email = "person@gmail.com" })).StatusCode);
            Assert.Equal(HttpStatusCode.TooManyRequests,
                (await client.PostAsJsonAsync("/api/beta/enroll", new { email = "person@gmail.com" })).StatusCode);
        }

        [Theory]
        [InlineData("GET", "/api/beta/status")]
        [InlineData("GET", "/api/beta/testers")]
        [InlineData("PATCH", "/api/beta/testers/test-id")]
        [InlineData("POST", "/api/beta/testers/test-id/retry-sync")]
        public async Task Admin_routes_require_authentication(string method, string path)
        {
            using var server = Server("test-key");
            using var client = server.CreateClient();
            using var request = new HttpRequestMessage(new HttpMethod(method), path);
            Assert.Equal(HttpStatusCode.Unauthorized, (await client.SendAsync(request)).StatusCode);
        }
    }
}
