/* Public configuration only. No secrets belong in this static website. */
window.VGO_CONFIG = Object.freeze({
  API_BASE: '', // Same origin: https://vgo-eg.com
  PACKAGE: 'com.scooterapp.vgo.v_go_captain',
  GOOGLE_CLIENT_ID: '792221536894-fmupld3v24c6q6d3pv029kk4nhv0lb78.apps.googleusercontent.com',
  SOURCE: 'site-captain',
  // Closed-testing opt-in: become a tester here before opening the Play listing.
  TEST_OPTIN_URL: 'https://play.google.com/apps/testing/com.scooterapp.vgo.v_go_captain',
  WHATSAPP: '', // TODO: V.Go support WhatsApp
  CONTACT_EMAIL: '', // TODO: V.Go privacy contact email
  POST_SYNC_SECONDS: 10,
  POLL_MS: 2000,
  MAX_HOLD_SECONDS: 300,
  REQUEST_TIMEOUT_MS: 15000
});
