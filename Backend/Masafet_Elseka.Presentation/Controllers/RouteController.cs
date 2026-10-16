using System.Globalization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Masafet_Elseka.Presentation.Controllers
{
    /// <summary>
    /// Road routes for the apps. Phones on Egyptian networks can't reach the
    /// public OSRM router (its TLS handshake fails), so the route line never
    /// drew; the server can, so the apps ask here and get OSRM's JSON back as is.
    /// </summary>
    [AllowAnonymous]
    [Route("api/[controller]")]
    [ApiController]
    public class RouteController : ControllerBase
    {
        private const string OsrmUrl = "https://router.project-osrm.org/route/v1/driving/";

        private readonly IHttpClientFactory _httpClientFactory;

        public RouteController(IHttpClientFactory httpClientFactory)
        {
            _httpClientFactory = httpClientFactory;
        }

        // GET api/Route?fromLat=..&fromLng=..&toLat=..&toLng=..&steps=true
        [HttpGet]
        public async Task<IActionResult> Get(double fromLat, double fromLng, double toLat, double toLng,
            bool steps = false, CancellationToken ct = default)
        {
            // Egypt only, so this can't be used as a free router for anywhere else.
            if (!InEgypt(fromLat, fromLng) || !InEgypt(toLat, toLng))
                return BadRequest(new { message = "خارج نطاق الخدمة" });

            var url = string.Create(CultureInfo.InvariantCulture,
                $"{OsrmUrl}{fromLng},{fromLat};{toLng},{toLat}?overview=full&geometries=polyline&steps={(steps ? "true" : "false")}");
            try
            {
                var client = _httpClientFactory.CreateClient();
                client.Timeout = TimeSpan.FromSeconds(8);
                client.DefaultRequestHeaders.UserAgent.ParseAdd("VGo-Backend/1.0");
                using var response = await client.GetAsync(url, ct);
                var body = await response.Content.ReadAsStringAsync(ct);
                if (!response.IsSuccessStatusCode)
                    return StatusCode(502, new { message = "تعذر تحميل المسار" });
                return Content(body, "application/json");
            }
            catch (Exception) when (!ct.IsCancellationRequested)
            {
                return StatusCode(502, new { message = "تعذر تحميل المسار" });
            }
        }

        private static bool InEgypt(double lat, double lng) =>
            lat is >= 21.5 and <= 32 && lng is >= 24.5 and <= 37;
    }
}
