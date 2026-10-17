/* Public configuration only. No secrets belong in this static website. */
window.VGO_CONFIG = Object.freeze({
  API_BASE: '', // Same origin: https://vgo-eg.com
  PACKAGE: 'com.scooterapp.vgo.v_go_captain',
  GOOGLE_CLIENT_ID: '792221536894-qlpar24br7eecn3fkhn4b5jdttjjiqn2.apps.googleusercontent.com',
  SOURCE: 'site-captain',
  // Internal-testing join page. Clear it once the closed track is live: closed
  // email-list testers install straight from the store listing.
  TEST_OPTIN_URL: 'https://play.google.com/apps/internaltest/4701056972618945302',
  WHATSAPP: '', // TODO: V.Go support WhatsApp
  CONTACT_EMAIL: '', // TODO: V.Go privacy contact email
  ACTIVATION_SECONDS: 90,
  RESYNCED_SECONDS: 45,
  POST_SYNC_SECONDS: 10,
  POLL_MS: 2000,
  MAX_HOLD_SECONDS: 75,
  MAX_EXTRA_EMAILS: 3,
  REQUEST_TIMEOUT_MS: 15000
});
