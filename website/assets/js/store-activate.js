/* Captain: Google account -> enroll -> sync -> Play Store app hand-off. */
(function () {
  'use strict';
  var CONFIG = window.VGO_CONFIG;
  var $ = function (id) { return document.getElementById(id); };
  if (!$('actOverlay')) return;
  function t(key) { return window.VGO_I18N.t('am.' + key); }
  function hide(id, value) { $(id).hidden = value; }
  var state = {
    generation: 0, phase: 'closed', email: '', idToken: '', synced: false,
    deadline: 0, holdDeadline: 0, pickerDeadline: 0, statusKey: '', errorKey: '',
    tick: null, poll: null, controllers: [], opener: null, inertElements: [],
    timings: null, timingLogged: false, pickerAttempt: 0
  };
  var gisInitialized = false, gisLoading = null;
  function mark(key) { if (state.timings) state.timings[key] = performance.now(); }
  // While things are on track the big "stay here" line says it all; the status
  // line only speaks up when something needs the captain's attention.
  var QUIET_STATUS = { working: true, propagating: true, opening: true };
  function status(key) {
    state.statusKey = key;
    $('actStatus').textContent = t(key) + ((key === 'delayed' || key === 'holdlong') && CONFIG.WHATSAPP ? ' ' + t('support') : '');
    hide('actStatus', !!QUIET_STATUS[key]);
  }
  function error(key) { state.errorKey = key; $('actErr').textContent = t(key); hide('actErr', false); }
  function support() {
    var wa = $('actDelayedWa'); wa.hidden = !CONFIG.WHATSAPP;
    if (CONFIG.WHATSAPP) wa.href = 'https://wa.me/' + CONFIG.WHATSAPP;
    else wa.removeAttribute('href');
  }
  function stopWork() {
    clearInterval(state.tick); clearTimeout(state.poll);
    state.controllers.forEach(function (controller) { controller.abort(); }); state.controllers = [];
    state.generation++;
  }
  function clearCredential() { state.idToken = ''; state.email = ''; $('actChosenEmail').textContent = ''; }
  function resetStages() {
    ['actPickerStage', 'actProgress', 'actErr', 'actOpenPlay', 'actSwitch', 'actDelayedWa', 'actRetry'].forEach(function (id) { hide(id, true); });
    $('actOpenPlay').removeAttribute('href');
    state.statusKey = ''; state.errorKey = ''; state.synced = false;
  }
  function receiveCredential(response) {
    // Button state identifies the exact attempt, including after closing/reopening.
    if (state.phase !== 'picking' || response.state !== String(state.pickerAttempt)) return;
    try {
      var token = response.credential;
      var encoded = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      var bytes = Uint8Array.from(atob(encoded), function (c) { return c.charCodeAt(0); });
      var claims = JSON.parse(new TextDecoder().decode(bytes));
      // Decode only to display the account. The backend verifies the signed token.
      if (typeof claims.email !== 'string' || !claims.email || !claims.exp || claims.exp * 1000 <= Date.now()) throw new Error('credential');
      mark('accountChosen'); stopWork(); resetStages(); state.phase = 'confirm';
      state.idToken = token; state.email = claims.email; $('actChosenEmail').textContent = claims.email;
    } catch (_) {
      state.phase = 'picker'; clearCredential(); error('accountError'); hide('actRetry', false);
      return;
    }
    // Picking the account is the go-ahead: no confirmation screen.
    enroll();
  }
  function isAndroid() { return /Android/i.test(navigator.userAgent || ''); }
  function playWebUrl() { return 'https://play.google.com/store/apps/details?id=' + CONFIG.PACKAGE; }
  // A closed-test app has no page on the Play website, so Android goes to the
  // Play Store app via intent: and never falls back to the web.
  // Chrome launches another app without asking only off a fresh tap; a launch
  // started by our timer gets its own "Continue to Google Play Store?" prompt.
  // That prompt is the one tap, so there is no second (market:) try that would
  // prompt again; our button appears only if the store still hasn't opened.
  var STORE_FALLBACK_MS = 8000;
  function openStore(onRefused) {
    if (!isAndroid()) { window.location.href = playWebUrl(); return; }
    var handedOff = false;
    function onHide() { if (document.hidden) handedOff = true; }
    document.addEventListener('visibilitychange', onHide);
    try { window.location.href = 'intent://details?id=' + CONFIG.PACKAGE + '#Intent;scheme=market;package=com.android.vending;end'; } catch (_) { /* scheme refused */ }
    setTimeout(function () {
      document.removeEventListener('visibilitychange', onHide);
      if (!handedOff && !document.hidden && onRefused) onRefused();
    }, STORE_FALLBACK_MS);
  }
  function gisReady() { return !!(window.google && window.google.accounts && window.google.accounts.id); }
  function ensureGIS() {
    if (gisReady()) return Promise.resolve();
    if (gisLoading) return gisLoading;
    // Loading never opens a popup: the visitor must tap the rendered Google button.
    gisLoading = new Promise(function (resolve, reject) {
      var script = document.querySelector('script[src^="https://accounts.google.com/gsi/client"]');
      if (script) script.remove();
      script = document.createElement('script'); script.src = 'https://accounts.google.com/gsi/client'; script.async = true;
      var timer = setTimeout(function () { finish(false); }, CONFIG.REQUEST_TIMEOUT_MS);
      function finish(ok) {
        clearTimeout(timer); script.onload = script.onerror = null;
        if (ok && gisReady()) resolve(); else reject(new Error('gis'));
      }
      script.onload = function () { finish(true); }; script.onerror = function () { finish(false); };
      document.head.appendChild(script);
    }).finally(function () { gisLoading = null; });
    return gisLoading;
  }
  function renderGoogleButton() {
    if (!gisInitialized) {
      window.google.accounts.id.initialize({
        client_id: CONFIG.GOOGLE_CLIENT_ID, callback: receiveCredential,
        ux_mode: 'popup', auto_select: false, button_auto_select: false, use_fedcm_for_button: false
      });
      gisInitialized = true;
    }
    var attempt = ++state.pickerAttempt;
    window.google.accounts.id.disableAutoSelect(); $('actGsiBtn').replaceChildren();
    // GIS has no custom-button popup API. This visible button owns the real user
    // gesture; do not synthesize clicks or substitute OAuth access tokens.
    window.google.accounts.id.renderButton($('actGsiBtn'), {
      type: 'standard', theme: 'outline', size: 'large', text: 'continue_with',
      width: Math.min(360, $('actGsiBtn').clientWidth), locale: document.documentElement.lang, state: String(attempt),
      click_listener: function () {
        if (attempt !== state.pickerAttempt || (state.phase !== 'picker' && state.phase !== 'picking')) return;
        state.phase = 'picking'; state.pickerDeadline = Date.now() + 60000;
        state.errorKey = ''; hide('actErr', true);
        // GIS has no popup-close callback. Keep retry visible even during choice.
        hide('actRetry', false); clearInterval(state.tick); state.tick = setInterval(render, 250);
      }
    });
  }
  function showPicker() {
    stopWork(); clearCredential(); resetStages(); state.phase = 'picker'; state.pickerAttempt++;
    if (state.timings) ['accountChosen', 'enrollResponse', 'synced', 'playRedirect'].forEach(function (key) { delete state.timings[key]; });
    state.timingLogged = false;
    hide('actPickerStage', false); hide('actRetry', false); $('actGsiBtn').replaceChildren();
    var generation = state.generation;
    function loaded() {
      if (generation !== state.generation || state.phase !== 'picker') return;
      try { renderGoogleButton(); } catch (_) { error('gisError'); }
    }
    if (!CONFIG.GOOGLE_CLIENT_ID) { error('gisError'); return; }
    if (gisReady()) loaded();
    else {
      error('gisLoading');
      ensureGIS().then(function () {
        if (generation !== state.generation) return;
        state.errorKey = ''; hide('actErr', true); loaded();
      }).catch(function () { if (generation === state.generation) error('gisError'); });
    }
  }
  function openModal(opener) {
    state.opener = opener; state.timings = { buttonClick: performance.now() };
    hide('actOverlay', false); document.body.style.overflow = 'hidden';
    state.inertElements = Array.from(document.body.children).filter(function (el) { return el !== $('actOverlay') && !el.inert && !/SCRIPT|STYLE/.test(el.tagName); });
    state.inertElements.forEach(function (el) { el.inert = true; });
    showPicker(); $('actClose').focus();
  }
  function closeModal() {
    stopWork(); state.phase = 'closed'; state.pickerAttempt++; clearCredential();
    $('actGsiBtn').replaceChildren(); hide('actOverlay', true); document.body.style.overflow = '';
    state.inertElements.forEach(function (el) { el.inert = false; }); state.inertElements = [];
    if (state.opener) state.opener.focus();
  }
  async function request(path, options, generation) {
    var controller = new AbortController(); state.controllers.push(controller);
    var timer = setTimeout(function () { controller.abort(); }, CONFIG.REQUEST_TIMEOUT_MS);
    try {
      var response = await fetch(CONFIG.API_BASE + path, Object.assign({}, options, { signal: controller.signal, cache: 'no-store', credentials: 'same-origin' }));
      if (generation !== state.generation) throw new Error('stale');
      if (!response.ok) throw new Error('network');
      return await response.json();
    } finally {
      clearTimeout(timer); state.controllers = state.controllers.filter(function (item) { return item !== controller; });
    }
  }
  function synced() {
    mark('synced'); state.synced = true; state.deadline = Date.now() + CONFIG.POST_SYNC_SECONDS * 1000;
    status('propagating'); hide('actWarn', false); hide('actDelayedWa', true);
  }
  function logTimings() {
    if (state.timingLogged || !state.timings) return;
    mark('playRedirect'); state.timingLogged = true;
    var start = state.timings.buttonClick;
    console.info('[vgo-activate] timings ms: ' + Object.keys(state.timings).map(function (key) {
      return key + '=' + Math.round(state.timings[key] - start);
    }).join(', '));
  }
  function ready() {
    stopWork(); state.phase = 'ready';
    hide('actDelayedWa', true); hide('actRetry', true); hide('actWarn', false); status('opening');
    $('actOpenPlay').href = playWebUrl();
    logTimings();
    var generation = state.generation;
    openStore(function () {
      if (generation !== state.generation || state.phase !== 'ready') return;
      hide('actProgSpin', true); hide('actWarn', true); status('openFallback'); hide('actOpenPlay', false); hide('actSwitch', false);
    });
  }
  function showDelayed() { status('delayed'); hide('actWarn', true); support(); }
  function render() {
    var now = Date.now();
    if (state.phase === 'picking' && now >= state.pickerDeadline) {
      stopWork(); state.phase = 'picker'; state.pickerAttempt++; error('pickerRetry');
      $('actGsiBtn').replaceChildren(); hide('actRetry', false); return;
    }
    if (state.phase !== 'enrolling' && state.phase !== 'waiting') return;
    if (state.synced && now >= state.deadline) { ready(); return; }
    if (now >= state.holdDeadline) {
      hide('actProgSpin', true);
      if (state.synced) { status('propagating'); return; }
      hide('actWarn', true);
      stopWork(); state.phase = 'delayed'; clearCredential(); support(); status('holdlong'); hide('actRetry', false);
    }
  }
  async function enroll() {
    if (state.phase !== 'confirm' || !state.idToken) return;
    var token = state.idToken;
    stopWork(); var generation = state.generation;
    resetStages(); state.phase = 'enrolling'; state.idToken = '';
    state.holdDeadline = Date.now() + CONFIG.MAX_HOLD_SECONDS * 1000;
    hide('actProgress', false); hide('actProgSpin', false); hide('actWarn', false); status('working');
    state.tick = setInterval(render, 250);
    try {
      var result = await request('/api/beta/enroll', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken: token, source: CONFIG.SOURCE, app: 'captain' })
      }, generation);
      if (generation !== state.generation) return;
      mark('enrollResponse'); render(); if (generation !== state.generation) return;
      if (result.rejected) { showPicker(); error('rejected'); return; }
      // The response carries no email; the backend verified the token, so poll with the decoded one.
      state.phase = 'waiting';
      if (result.playSynced === true) synced();
      else {
        if (result.delayed) showDelayed();
        state.poll = setTimeout(function () { poll(generation); }, CONFIG.POLL_MS);
      }
      render();
    } catch (err) {
      if (generation !== state.generation) return;
      showPicker(); error(err.message === 'account' ? 'accountError' : 'network');
    }
  }
  async function poll(generation) {
    if (generation !== state.generation || state.phase !== 'waiting') return;
    var result = await request('/api/beta/enroll/status?email=' + encodeURIComponent(state.email) + '&app=captain', {}, generation).catch(function () { return null; });
    if (generation !== state.generation) return;
    render(); if (generation !== state.generation) return;
    if (result && result.rejected) { showPicker(); error('rejected'); return; }
    if (result && result.synced === true) synced();
    else {
      if (result && result.delayed) showDelayed();
      state.poll = setTimeout(function () { poll(generation); }, CONFIG.POLL_MS);
    }
    render();
  }
  function openPlay(event) {
    if (state.phase !== 'ready') { event.preventDefault(); return; }
    // The href stays the web listing (long-press, no-JS); a real tap on Android
    // gives Chrome the activation it needs to open the Play Store app.
    if (isAndroid()) { event.preventDefault(); openStore(); }
  }
  document.querySelectorAll('.js-play-activate').forEach(function (button) {
    button.addEventListener('click', function (event) { event.preventDefault(); openModal(button); });
  });
  $('actClose').addEventListener('click', closeModal);
  $('actOverlay').addEventListener('click', function (event) { if (event.target === $('actOverlay')) closeModal(); });
  $('actRetry').addEventListener('click', showPicker);
  $('actOpenPlay').addEventListener('click', openPlay);
  document.addEventListener('visibilitychange', function () { if (!document.hidden) render(); });
  document.addEventListener('keydown', function (event) {
    if ($('actOverlay').hidden) return;
    if (event.key === 'Escape') { closeModal(); return; }
    if (event.key !== 'Tab') return;
    var focusable = Array.from($('actOverlay').querySelectorAll('button:not([disabled]),a[href],iframe,[tabindex="0"]')).filter(function (el) { return el.getClientRects().length > 0; });
    var first = focusable[0], last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  });
  document.addEventListener('vgo:language', function () {
    if (state.statusKey) status(state.statusKey);
    if (state.errorKey) error(state.errorKey);
    if (state.phase === 'picker' && gisReady()) renderGoogleButton();
  });
})();
