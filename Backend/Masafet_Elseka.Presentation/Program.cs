#region Usings
using FirebaseAdmin;
using FluentValidation;
using Google.Apis.Auth.OAuth2;
using Hangfire;
using Hangfire.SqlServer;
using MailKit;
using IMailService = Masafet_Elseka.Domain.ExternalInterfaces.IMailService;
using MailService = Masafet_Elseka.Infrastructure.ExternalService.MailService.MailService;
using Masafet_Elseka.Application.Common;
using Masafet_Elseka.Application.DTOs;

using Masafet_Elseka.Application.ExternalInterfaces;
using Masafet_Elseka.Application.Interfaces;
using Masafet_Elseka.Infrastructure.Services;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using System.Threading.RateLimiting;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.ExternalInterfaces.ICloudinaryService;
using Masafet_Elseka.Application.ExternalInterfaces.IFirebaseNotificationService;
using Masafet_Elseka.Application.Interfaces.HomeBanner;
using Masafet_Elseka.Application.Interfaces.IAccountantService;
using Masafet_Elseka.Application.Interfaces.IAuthService;
using Masafet_Elseka.Application.Interfaces.IChatService;
using Masafet_Elseka.Application.Interfaces.IDispatcherService;
using Masafet_Elseka.Application.Interfaces.IDriverService;
using Masafet_Elseka.Application.Interfaces.IEmergencyService;
using Masafet_Elseka.Application.Interfaces.IExpenseService;
using Masafet_Elseka.Application.Interfaces.IMessageService;
using Masafet_Elseka.Application.Interfaces.INotificationService;
using Masafet_Elseka.Application.Interfaces.IPaymentService;
using Masafet_Elseka.Application.Interfaces.IPricingRuleService;
using Masafet_Elseka.Application.Interfaces.IRatingService;
using Masafet_Elseka.Application.Interfaces.ITripService;
using Masafet_Elseka.Application.Interfaces.IUserTripService;
using Masafet_Elseka.Application.Interfaces.Statistics;
using Masafet_Elseka.Application.Interfaces.User;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.ExternalInterfaces;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.ExternalService.CachService;
using Masafet_Elseka.Infrastructure.ExternalService.ChatBGService;
using Masafet_Elseka.Infrastructure.ExternalService.CloudinaryService;
using Masafet_Elseka.Infrastructure.ExternalService.FirebaseNotificationService;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.AuthState;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.GoogleAuthManagerService;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.GoogleAuthService;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.HTMLResponseService;
using Masafet_Elseka.Infrastructure.ExternalService.JWTService;
using Masafet_Elseka.Infrastructure.ExternalService.MailService;
using Masafet_Elseka.Infrastructure.ExternalService.UserCleanUpService;
using Masafet_Elseka.Infrastructure.Hubs;
using Masafet_Elseka.Infrastructure.Services.AccountatService;
using Masafet_Elseka.Infrastructure.Services.AuthService;
using Masafet_Elseka.Infrastructure.Services.ChatService;
using Masafet_Elseka.Infrastructure.Services.DispatcherService;
using Masafet_Elseka.Infrastructure.Services.DriverService;
using Masafet_Elseka.Infrastructure.Services.EmergencyService;
using Masafet_Elseka.Infrastructure.Services.ExpenseService;
using Masafet_Elseka.Infrastructure.Services.HomeBanner;
using Masafet_Elseka.Infrastructure.Services.MessageService;
using Masafet_Elseka.Infrastructure.Services.NotificationService;
using Masafet_Elseka.Infrastructure.Services.OnlineTrackerService;
using Masafet_Elseka.Infrastructure.Services.PaymentService;
using Masafet_Elseka.Infrastructure.Services.PricingRoleService;
using Masafet_Elseka.Infrastructure.Services.RatingService;
using Masafet_Elseka.Infrastructure.Services.StatisticsService;
using Masafet_Elseka.Infrastructure.Services.TripService;
using Masafet_Elseka.Infrastructure.Services.UserService;
using Masafet_Elseka.Infrastructure.Services.UserTripService;
using Masafet_Elseka.Infrastructure.UOW;
using Masafet_Elseka.Infrastructure.Validations;
using Masafet_Elseka.Presentation.SwaggerConfigurations;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using System.Text;
#endregion

var builder = WebApplication.CreateBuilder(args);

#region Cloud Run port binding

// Cloud Run injects the port to listen on via the PORT env var (default 8080).
var port = Environment.GetEnvironmentVariable("PORT");
if (!string.IsNullOrEmpty(port))
{
    builder.WebHost.UseUrls($"http://0.0.0.0:{port}");
}

#endregion

#region Services

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.ConfigureSwagger();
builder.Services.AddDistributedMemoryCache();
builder.Services.AddValidatorsFromAssemblyContaining<ScooterValidator>();

#endregion

#region Database

// Cap the EF connection pool PER INSTANCE so Cloud Run scale-out can't exhaust
// Cloud SQL's connection limit. (max instances × pool must stay under the DB max.)
var baseConn = (builder.Configuration.GetConnectionString("DefaultConnection") ?? string.Empty).TrimEnd(';');
var efConn = baseConn.Contains("Max Pool Size", StringComparison.OrdinalIgnoreCase)
    ? baseConn
    : $"{baseConn};Max Pool Size=30;Min Pool Size=2;Connect Timeout=15";
// Hangfire gets its OWN small, separate pool (distinct Application Name) so its
// long-held lock/poll connections can't starve app requests.
var hangfireConn = $"{baseConn};Application Name=VGoHangfire;Max Pool Size=10;Min Pool Size=1;Connect Timeout=15";

builder.Services.AddDbContext<Context>(options =>
    options.UseSqlServer(efConn));

// ----- Test (development)
//builder.Services.AddDbContext<Context>(options =>
//    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnectionTest")));

#endregion

#region Hangfire

builder.Services.AddHangfire(config =>
    config.UseSqlServerStorage(hangfireConn, new SqlServerStorageOptions
    {
        // Less aggressive polling + sliding locks = far fewer connections held,
        // which is what exhausted the pool under load.
        QueuePollInterval = TimeSpan.FromSeconds(30),
        SlidingInvisibilityTimeout = TimeSpan.FromMinutes(5),
        UseRecommendedIsolationLevel = true,
        DisableGlobalLocks = true,
    }));
builder.Services.AddHangfireServer(options =>
{
    options.WorkerCount = 4;          // was the default (~20) — caps concurrent DB work
    options.SchedulePollingInterval = TimeSpan.FromSeconds(30);
});

#endregion

#region Identity

builder.Services.AddIdentity<ApplicationUser, IdentityRole>(options =>
{
    // Allow simple passwords (e.g. a 6-digit PIN); the apps enforce a 6-char
    // minimum. Complexity rules off so phone users aren't blocked.
    options.Password.RequiredLength = 6;
    options.Password.RequireDigit = false;
    options.Password.RequireLowercase = false;
    options.Password.RequireUppercase = false;
    options.Password.RequireNonAlphanumeric = false;
    options.Password.RequiredUniqueChars = 1;
})
    .AddEntityFrameworkStores<Context>()
    .AddErrorDescriber<Masafet_Elseka.Presentation.Identity.ArabicIdentityErrorDescriber>()
    .AddDefaultTokenProviders();

#endregion

#region Mail

builder.Services.Configure<MailSettingsDTO>(
    builder.Configuration.GetSection("MailSettings"));
builder.Services.AddScoped<IMailService, MailService>();
// builder.Services.AddScoped<
//     Masafet_Elseka.Domain.ExternalInterfaces.IMailService,
//     Masafet_Elseka.Infrastructure.ExternalService.MailService.MailService
// >();


// #endregion

// #region SignalR

// builder.Services.AddSignalR(options =>
// {
//     options.EnableDetailedErrors = true;
// });

#endregion

#region SignalR

builder.Services.AddSignalR(options =>
{
    // Detailed errors only in Development to avoid leaking internals to clients.
    options.EnableDetailedErrors = builder.Environment.IsDevelopment();

    // Prevent disconnect
    options.KeepAliveInterval = TimeSpan.FromSeconds(15);
    options.ClientTimeoutInterval = TimeSpan.FromSeconds(60);
});

#endregion


#region Hosted Services

builder.Services.AddHostedService<DriverStatusSyncService>();
builder.Services.AddHostedService<PreAuthExpiryService>();

#endregion

#region Dependency Injection

builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IJWTService, JWTService>();
builder.Services.AddScoped<ICacheService, CacheService>();
builder.Services.AddScoped<IDriverService, DriverService>();
builder.Services.AddScoped<ICloudinaryService, CloudinaryService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IPricingRuleService, PricingRuleService>();
builder.Services.AddScoped<ITripService, TripService>();
builder.Services.AddScoped<IUserTripService, UserTripService>();
builder.Services.AddScoped<IUserCleanupService, UserCleanupService>();
builder.Services.AddScoped<IStatisticsService, StatisticsService>();
builder.Services.AddScoped<IChatService, ChatService>();
builder.Services.AddScoped<IMessageService, MessageService>();
builder.Services.AddScoped<IDispatcherService, DispatcherService>();
builder.Services.AddScoped<IAccountantService, AccountantService>();
builder.Services.AddScoped<IExpenseService, ExpenseService>();
builder.Services.AddScoped<IRatingService, RatingService>();
//builder.Services.AddScoped<IDriverNotifier, DriverNotifier>();
builder.Services.AddScoped<IPaymentService, PaymentService>();
builder.Services.AddScoped<IFirebaseNotificationService, FirebaseNotificationService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<IEmergencyService, EmergencyService>();
builder.Services.AddScoped<IGoogleAuthManager, GoogleAuthManager>();
builder.Services.AddScoped<IHtmlResponseService, HtmlResponseService>();
builder.Services.AddSingleton<IAuthStateService, AuthStateService>();
builder.Services.AddScoped<IGoogleAuthService, GoogleAuthService>();
builder.Services.AddScoped<IHomeBannerService, HomeBannerService>();
builder.Services.AddSingleton<OnlineTrackerService>();
builder.Services.AddScoped<Masafet_Elseka.Application.Common.OTP>();
#endregion

#region HttpClient

builder.Services.AddHttpClient();

#endregion

#region Authentication & JWT

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.SaveToken = true;
    // Require HTTPS metadata in production; relax only in Development.
    options.RequireHttpsMetadata = !builder.Environment.IsDevelopment();

    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,

        IssuerSigningKey = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(builder.Configuration["JWT:Key"] ?? throw new InvalidOperationException("JWT Key not found in Config"))),

        ValidIssuer = builder.Configuration["JWT:Issuer"],
        ValidAudience = builder.Configuration["JWT:Audience"],
        ClockSkew = TimeSpan.Zero
    };

    options.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;

            if (!string.IsNullOrEmpty(accessToken) &&
                (path.StartsWithSegments("/tripHub") ||
                 path.StartsWithSegments("/driverHub") ||
                 path.StartsWithSegments("/supportChatHub") ||
                 path.StartsWithSegments("/ratingHub")))
            {
                context.Token = accessToken;
            }

            return Task.CompletedTask;
        }
    };
});

#endregion

#region Firebase

// Firebase credentials resolution order:
//   1. FIREBASE_CREDENTIALS_PATH env var (e.g. a Secret Manager volume mount on Cloud Run)
//   2. the bundled file under appdata/secrets (local development)
//   3. Application Default Credentials (Cloud Run service account in the same GCP project)
var rootPath = builder.Environment.ContentRootPath;
var firebasePath = Environment.GetEnvironmentVariable("FIREBASE_CREDENTIALS_PATH")
    ?? Path.Combine(rootPath, "appdata", "secrets", "v-go-46d8c-firebase-adminsdk-fbsvc-bbf1f90567.json");

GoogleCredential firebaseCredential = System.IO.File.Exists(firebasePath)
    ? GoogleCredential.FromFile(firebasePath)
    : GoogleCredential.GetApplicationDefault();

FirebaseApp.Create(new AppOptions
{
    Credential = firebaseCredential
});

#endregion


#region Rate Limiting

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    // Limiter for auth/OTP endpoints: 20 requests / minute per client IP.
    // The phone+password flow makes ~2 calls per login (phone-exists + sign-in),
    // so 20/min still blocks brute-forcing while not locking out normal use.
    options.AddPolicy("auth", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));

    // Global fallback limiter: 100 requests / minute per client IP.
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 100,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));
});

#endregion

#region CORS

builder.Services.AddCors(options =>
{
    options.AddPolicy("Default", policy =>
    {
        // Production origins only; localhost is added in Development.
        var origins = new List<string>
        {
            "https://vgo-eg.com",
            "https://www.vgo-eg.com",
            "https://v-go-two.vercel.app",
            "https://vgo-admin-792221536894.europe-west1.run.app",
        };
        if (builder.Environment.IsDevelopment())
        {
            origins.Add("http://127.0.0.1:5500");
            origins.Add("http://localhost:5173");
        }

        policy.WithOrigins(origins.ToArray())
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});

#endregion

#region Serilog

// Log to stdout so Google Cloud Logging captures it (the container FS is ephemeral).
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .CreateLogger();

builder.Logging.ClearProviders();
builder.Logging.AddSerilog();

#endregion

var app = builder.Build();

#region Database Migration

// Apply any pending EF Core migrations on startup so a fresh Cloud SQL database
// is provisioned automatically on first boot.
using (var scope = app.Services.CreateScope())
{
    try
    {
        var db = scope.ServiceProvider.GetRequiredService<Context>();
        db.Database.Migrate();
        Log.Information("Database migrations applied successfully");
    }
    catch (Exception ex)
    {
        Log.Error(ex, "Database migration failed on startup");
    }
}

#endregion

#region Middleware

// Swagger is exposed only in Development — never on production.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
// Add this BEFORE UseAuthentication / UseAuthorization
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});

// Cloud Run terminates TLS at the edge and forwards plain HTTP on $PORT, so
// HTTPS redirection would break health checks there. Only redirect locally.
if (app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseRouting();
app.UseWebSockets();

app.UseCors("Default");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

#endregion

#region Hangfire Dashboard

// development
//if (app.Environment.IsDevelopment())
//{
//app.UseHangfireDashboard();
//}

app.UseHangfireDashboard("/hangfire", new DashboardOptions
{
    Authorization = new[] { new HangfireAuthorizationFilter() }
});

#endregion

#region Endpoints

app.MapHub<DriverHub>("/driverHub");
app.MapHub<TripHub>("/tripHub");
app.MapHub<SupportChatHub>("/supportChatHub");
app.MapHub<TripChatHub>("/tripChatHub");
app.MapHub<RatingHub>("/ratingHub");

app.MapControllers();

#endregion

app.Run();