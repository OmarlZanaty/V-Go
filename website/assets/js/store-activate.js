/* V.Go Captain: port of Cairo Shuttle Bus's account picker → enroll → poll →
 * propagation → user-tapped Play Store handoff. See README for preserved rules.
 * Wall-clock deadlines also bound enrollment requests, background tabs and retries.
 */
(function () {
  'use strict';
  var CONFIG = window.VGO_CONFIG;
  var $ = function (id) { return document.getElementById(id); };
  if (!$('actOverlay')) return;
  var STR = {
    ar: {
      working: 'جارِ تفعيل التحميل لحسابك…',
      propagating: 'تم تأكيد التفعيل — بنجهّز التحميل على Google Play…',
      ready: 'التحميل جاهز. اضغط الزر لفتح Google Play.',
      delayed: 'التفعيل متأخر حاليًا. تقدر ترجع وتحاول بعد شوية، أو تستخدم رابط APK المباشر في الصفحة.',
      holdlong: 'التفعيل بياخد وقت أطول من المعتاد. جرّب التفعيل تاني بعد شوية، أو استخدم رابط APK في الصفحة.',
      support: 'تقدر تتواصل معانا على واتساب للمساعدة.',
      rejected: 'العنوان ده مش مقبول كحساب Google. صحّحه أو احذفه، واستخدم حساب المتجر على هاتفك:',
      badEmail: 'اكتب بريدًا إلكترونيًا صحيحًا للحساب الأساسي ولكل حساب إضافي.',
      network: 'تعذّر إكمال الاتصال. تأكد من الإنترنت وجرّب تاني.',
      missingEmail: 'تعذّر معرفة بريد الحساب. اكتبه يدويًا لإكمال التفعيل.',
      extra: 'بريد حساب Google إضافي',
      remove: 'حذف الحساب الإضافي',
      handoff: 'لو المتجر ما اتفتحش، اضغط فتح Google Play مرة تانية. من المتصفح الداخلي، جرّب فتح الموقع في متصفح هاتفك.'
    },
    en: {
      working: 'Activating the download for your account…',
      propagating: 'Activation confirmed — preparing your Google Play download…',
      ready: 'Your download is ready. Tap below to open Google Play.',
      delayed: 'Activation is delayed right now. You can return and retry later, or use the direct APK link on the page.',
      holdlong: 'Activation is taking longer than usual. Please retry later, or use the APK link on the page.',
      support: 'You can contact us on WhatsApp for help.',
      rejected: 'This address was not accepted as a Google account. Correct or remove it and use your phone’s Play Store account:',
      badEmail: 'Enter a valid email for the main account and every extra account.',
      network: 'Could not complete the connection. Check your internet and try again.',
      missingEmail: 'We could not identify the account email. Please enter it manually to continue.',
      extra: 'Additional Google account email',
      remove: 'Remove extra account',
      handoff: 'If the store did not open, tap Open Google Play again. In an in-app browser, try opening this site in your phone’s browser.'
    }
  };
  function t(key) { return STR[document.documentElement.lang === 'en' ? 'en' : 'ar'][key] || key; }
  var state = {
    generation: 0, phase: 'closed', emails: [], synced: false,
    deadline: 0, holdDeadline: 0, manualDeadline: 0, statusKey: '', errorKey: '', rejectedEmail: '',
    tick: null, poll: null, fallback: null, gisWait: null, controllers: [],
    opener: null, handoffTimers: [], handoffListener: null, inertElements: []
  };
  function hide(id, value) { $(id).hidden = value; }
  function status(key) {
    state.statusKey = key;
    $('actStatus').textContent = t(key) + ((key === 'delayed' || key === 'holdlong') && CONFIG.WHATSAPP ? ' ' + t('support') : '');
  }
  function error(key, address) {
    state.errorKey = key; state.rejectedEmail = address || '';
    $('actErr').textContent = t(key) + (address ? ' ' + address : '');
    hide('actErr', false);
  }
  function support() {
    var wa = $('actDelayedWa');
    wa.hidden = !CONFIG.WHATSAPP;
    if (CONFIG.WHATSAPP) wa.href = 'https://wa.me/' + CONFIG.WHATSAPP;
    else wa.removeAttribute('href');
  }
  function cancelGIS() {
    try { if (window.google && window.google.accounts) window.google.accounts.id.cancel(); } catch (_) {}
  }
  function clearHandoff() {
    state.handoffTimers.forEach(clearTimeout); state.handoffTimers = [];
    if (state.handoffListener) document.removeEventListener('visibilitychange', state.handoffListener);
    state.handoffListener = null;
  }
  function stopWork() {
    clearInterval(state.tick); clearTimeout(state.poll); clearTimeout(state.fallback); clearInterval(state.gisWait);
    state.controllers.forEach(function (controller) { controller.abort(); }); state.controllers = [];
    state.generation++;
    cancelGIS(); clearHandoff();
  }
  function resetForm() {
    stopWork(); state.phase = 'form'; state.synced = false; state.statusKey = ''; state.errorKey = ''; state.rejectedEmail = '';
    ['actProgress','actErr','actSpin','actPickSpin','actPickerStage','actOpenPlay','actSwitch','actDelayedWa','actRetry'].forEach(function (id) { hide(id, true); });
    hide('actFormStage', false); hide('actWarn', false); hide('actProgSpin', false);
    $('actGo').disabled = false; $('actStatus').textContent = '';
  }
  function manual() {
    if (state.phase !== 'form') return;
    cancelGIS(); clearTimeout(state.fallback); clearInterval(state.gisWait);
    hide('actPickerStage', true); hide('actFormStage', false); $('actEmail').focus();
  }
  function webview() { return /FBAN|FBAV|FB_IAB|Instagram|Line\/|Twitter|WhatsApp|; wv\)/i.test(navigator.userAgent || ''); }
  function gisReady() { return !!(window.google && window.google.accounts && window.google.accounts.id); }
  function tryPicker() {
    if (state.phase !== 'form' || !gisReady() || webview()) return false;
    var generation = state.generation;
    try {
      window.google.accounts.id.initialize({
        client_id: CONFIG.GOOGLE_CLIENT_ID, auto_select: true, cancel_on_tap_outside: false,
        callback: function (response) {
          if (generation !== state.generation || state.phase !== 'form' || !response.credential) return;
          enrollAll(null, response.credential);
        }
      });
      // No renderButton: the fallback must never navigate to Google's sign-in page.
      window.google.accounts.id.prompt(function () {});
      return true;
    } catch (_) { return false; }
  }
  function openModal(opener) {
    state.opener = opener;
    resetForm(); $('actForm').reset(); $('actExtra').replaceChildren(); $('actAddMore').disabled = false;
    hide('actOverlay', false); document.body.style.overflow = 'hidden';
    state.inertElements = Array.from(document.body.children).filter(function (el) { return el !== $('actOverlay') && !el.inert && !/SCRIPT|STYLE/.test(el.tagName); });
    state.inertElements.forEach(function (el) { el.inert = true; });
    $('actClose').focus();
    if (webview() || !CONFIG.GOOGLE_CLIENT_ID) { manual(); return; }
    hide('actFormStage', true); hide('actPickerStage', false);
    state.manualDeadline = Date.now() + 2500;
    state.fallback = setTimeout(manual, 2500);
    if (!tryPicker()) state.gisWait = setInterval(function () {
      if (state.phase !== 'form' || Date.now() >= state.manualDeadline) { clearInterval(state.gisWait); manual(); return; }
      if (tryPicker()) clearInterval(state.gisWait);
    }, 250);
  }
  function closeModal() {
    stopWork(); state.phase = 'closed'; state.emails = [];
    hide('actOverlay', true); document.body.style.overflow = '';
    state.inertElements.forEach(function (el) { el.inert = false; }); state.inertElements = [];
    $('actForm').reset(); $('actExtra').replaceChildren();
    if (state.opener) state.opener.focus();
  }
  function addExtra() {
    var host = $('actExtra');
    if (host.querySelectorAll('input').length >= CONFIG.MAX_EXTRA_EMAILS) return;
    var row = document.createElement('div'); row.className = 'act-extra-row';
    var input = document.createElement('input'); input.className = 'act-input'; input.type = 'email'; input.inputMode = 'email'; input.dir = 'ltr'; input.autocomplete = 'email'; input.placeholder = 'another@gmail.com'; input.setAttribute('aria-label', t('extra'));
    var remove = document.createElement('button'); remove.type = 'button'; remove.textContent = '×'; remove.setAttribute('aria-label', t('remove'));
    remove.addEventListener('click', function () { row.remove(); $('actAddMore').disabled = false; $('actAddMore').focus(); });
    row.append(input, remove); host.appendChild(row); input.focus();
    $('actAddMore').disabled = host.querySelectorAll('input').length >= CONFIG.MAX_EXTRA_EMAILS;
  }
  function collectEmails() {
    var inputs = [$('actEmail')].concat(Array.from($('actExtra').querySelectorAll('input')));
    var emails = [];
    for (var i = 0; i < inputs.length; i++) {
      var email = inputs[i].value.trim().toLowerCase();
      if (!email && i > 0) continue;
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) { inputs[i].focus(); return null; }
      if (emails.indexOf(email) === -1) emails.push(email);
    }
    return emails;
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
  function rejected(email) {
    resetForm(); error('rejected', email); $('actEmail').focus();
  }
  function ready() {
    stopWork(); state.phase = 'ready'; hide('actProgSpin', true); hide('actWarn', true);
    hide('actDelayedWa', true); hide('actRetry', true); status('ready');
    $('actOpenPlay').href = storeUrl(); hide('actOpenPlay', false); hide('actSwitch', false);
    // Never launch on a timer, on Android OR desktop. A fresh user tap owns handoff.
  }
  function showDelayed() { status('delayed'); hide('actWarn', true); support(); }
  function render() {
    if (state.phase !== 'enrolling' && state.phase !== 'waiting') return;
    var now = Date.now();
    if (state.synced && now >= state.deadline) { ready(); return; }
    // Check the cap BEFORE the activation estimate. 90 seconds must not mask 75.
    if (now >= state.holdDeadline) {
      hide('actProgSpin', true); hide('actWarn', true); support();
      if (state.synced) { status('propagating'); return; } // Finish the full 10-second propagation without a spinner.
      stopWork(); state.phase = 'delayed'; status('holdlong'); hide('actRetry', false);
    }
  }
  async function enrollAll(emails, idToken) {
    if (state.phase !== 'form') return;
    stopWork(); var generation = state.generation;
    state.phase = 'enrolling'; state.synced = false; state.emails = []; state.errorKey = '';
    state.holdDeadline = Date.now() + CONFIG.MAX_HOLD_SECONDS * 1000;
    state.deadline = Date.now() + CONFIG.ACTIVATION_SECONDS * 1000;
    hide('actErr', true); hide('actFormStage', true); hide('actPickerStage', true); hide('actProgress', false);
    hide('actProgSpin', false); hide('actWarn', false); status('working');
    $('actGo').disabled = true; state.tick = setInterval(render, 250);
    var allSynced = true, delayed = false, alreadyEnrolled = true;
    var payloads = idToken ? [{ idToken: idToken }] : emails.map(function (email) { return { email: email }; });
    try {
      for (var i = 0; i < payloads.length; i++) {
        if (generation !== state.generation) return;
        var body = Object.assign({}, payloads[i], { source: CONFIG.SOURCE });
        var result = await request('/api/beta/enroll', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }, generation);
        if (generation !== state.generation) return;
        var email = result.email || payloads[i].email;
        if (result.rejected) { rejected(email || ''); return; }
        if (!email) throw new Error('missingEmail');
        state.emails.push(email); allSynced = allSynced && result.playSynced === true;
        alreadyEnrolled = alreadyEnrolled && result.alreadyEnrolled === true;
        delayed = delayed || result.delayed === true;
        if (result.delayed && !result.playSynced) showDelayed();
      }
      if (generation !== state.generation) return;
      state.phase = 'waiting';
      if (allSynced) {
        state.synced = true; state.deadline = Date.now() + CONFIG.POST_SYNC_SECONDS * 1000; status('propagating');
      } else {
        state.deadline = Date.now() + (alreadyEnrolled ? CONFIG.RESYNCED_SECONDS : CONFIG.ACTIVATION_SECONDS) * 1000;
        if (delayed) showDelayed();
        state.poll = setTimeout(function () { poll(generation); }, CONFIG.POLL_MS);
      }
      render();
    } catch (err) {
      if (generation !== state.generation) return;
      resetForm(); error(err.message === 'missingEmail' ? 'missingEmail' : 'network'); $('actEmail').focus();
    }
  }
  async function poll(generation) {
    if (generation !== state.generation || state.phase !== 'waiting') return;
    var results = await Promise.all(state.emails.map(function (email) {
      return request('/api/beta/enroll/status?email=' + encodeURIComponent(email), {}, generation).catch(function () { return null; });
    }));
    if (generation !== state.generation) return;
    for (var i = 0; i < results.length; i++) {
      if (results[i] && results[i].rejected) { rejected(state.emails[i]); return; }
    }
    if (results.length && results.every(function (r) { return r && r.synced === true; })) {
      state.synced = true;
      // Always ten full seconds from confirmation, even after a throttled interval.
      state.deadline = Date.now() + CONFIG.POST_SYNC_SECONDS * 1000;
      status('propagating'); hide('actDelayedWa', true);
    } else {
      if (results.some(function (r) { return r && r.delayed; })) showDelayed();
      state.poll = setTimeout(function () { poll(generation); }, CONFIG.POLL_MS);
    }
    render();
  }
  function storeUrl() { return 'https://play.google.com/store/apps/details?id=' + CONFIG.PACKAGE; }
  function openStore(event) {
    if (!/Android/i.test(navigator.userAgent || '')) return; // Desktop link remains a user-initiated normal URL.
    event.preventDefault(); clearHandoff();
    var handedOff = false;
    state.handoffListener = function () { if (document.hidden) handedOff = true; };
    document.addEventListener('visibilitychange', state.handoffListener);
    function go(url) { if (handedOff || document.hidden) return; try { window.location.href = url; } catch (_) {} }
    go('intent://details?id=' + CONFIG.PACKAGE + '#Intent;scheme=market;package=com.android.vending;end');
    state.handoffTimers.push(setTimeout(function () { go('market://details?id=' + CONFIG.PACKAGE); }, 2500));
    state.handoffTimers.push(setTimeout(function () {
      if (!handedOff && !document.hidden && state.phase === 'ready') status('handoff');
      clearHandoff();
    }, 6000));
  }
  document.querySelectorAll('.js-play-activate').forEach(function (button) {
    button.addEventListener('click', function (event) { event.preventDefault(); openModal(button); });
  });
  $('actClose').addEventListener('click', closeModal);
  $('actOverlay').addEventListener('click', function (event) { if (event.target === $('actOverlay')) closeModal(); });
  $('actAddMore').addEventListener('click', addExtra);
  $('actManualLink').addEventListener('click', manual);
  $('actOpenPlay').addEventListener('click', openStore);
  $('actRetry').addEventListener('click', function () { resetForm(); $('actEmail').focus(); });
  $('actForm').addEventListener('submit', function (event) { event.preventDefault(); var emails = collectEmails(); if (!emails) { error('badEmail'); return; } enrollAll(emails, null); });
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) return;
    if (state.phase === 'form' && !$('actPickerStage').hidden && Date.now() >= state.manualDeadline) manual();
    render();
  });
  document.addEventListener('keydown', function (event) {
    if ($('actOverlay').hidden) return;
    if (event.key === 'Escape') { closeModal(); return; }
    if (event.key !== 'Tab') return;
    var focusable = Array.from($('actOverlay').querySelectorAll('button:not([disabled]),a[href],input')).filter(function (el) { return el.getClientRects().length > 0; });
    var first = focusable[0], last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  });
  document.addEventListener('vgo:language', function () {
    if (state.statusKey) status(state.statusKey);
    if (state.errorKey) error(state.errorKey, state.rejectedEmail);
    $('actExtra').querySelectorAll('input').forEach(function (el) { el.setAttribute('aria-label', t('extra')); });
    $('actExtra').querySelectorAll('button').forEach(function (el) { el.setAttribute('aria-label', t('remove')); });
  });
})();
