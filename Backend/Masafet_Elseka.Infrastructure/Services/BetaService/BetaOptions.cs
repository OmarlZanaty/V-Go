namespace Masafet_Elseka.Infrastructure.Services.BetaService
{
    public class BetaOptions
    {
        public string? SyncKey { get; init; }
        public string? GoogleOAuthClientId { get; init; }
        public string PlayUrl { get; init; } = "https://play.google.com/store/apps/details?id=com.scooterapp.vgo.v_go_captain";
        public string ApkUrl { get; init; } = "https://vgo.almobarmg.com/downloads/vgo-captain.apk";
        public int TargetTesters { get; init; } = 20;

        public static BetaOptions FromEnvironment()
        {
            string? Read(string key) => Environment.GetEnvironmentVariable(key) is { } value
                && !string.IsNullOrWhiteSpace(value) ? value : null;
            var defaults = new BetaOptions();
            return new BetaOptions
            {
                SyncKey = Read("BETA_SYNC_KEY"),
                GoogleOAuthClientId = Read("GOOGLE_OAUTH_CLIENT_ID"),
                PlayUrl = Read("BETA_PLAY_URL") ?? defaults.PlayUrl,
                ApkUrl = Read("BETA_APK_URL") ?? defaults.ApkUrl,
                TargetTesters = int.TryParse(Read("BETA_TARGET_TESTERS"), out var target) && target > 0
                    ? target : defaults.TargetTesters
            };
        }
    }
}
