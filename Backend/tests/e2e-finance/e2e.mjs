// End-to-end test for captain finance + verification, run against the STAGING backend
// (its own database). Drives the real REST API and SignalR hubs like the apps do.
//
//   PHASE=setup  node e2e.mjs   -> admin, pricing, a captain registered before launch
//   (restart the backend so the launch bootstrap runs)
//   PHASE=main   node e2e.mjs   -> everything else
//   PHASE=overdue node e2e.mjs  -> after the grace deadline is moved into the past
//
// Env: BASE (default http://127.0.0.1:8090), HMAC (staging Paymob HMAC secret).
import * as signalR from '@microsoft/signalr';
import crypto from 'node:crypto';
import fs from 'node:fs';

const BASE = process.env.BASE ?? 'http://127.0.0.1:8090';
const API = `${BASE}/api/`;
const PHASE = process.env.PHASE ?? 'main';
const STATE_FILE = './state.json';
const state = fs.existsSync(STATE_FILE) ? JSON.parse(fs.readFileSync(STATE_FILE, 'utf8')) : {};
const save = () => fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));

let passed = 0, failed = 0;
const results = [];
function check(name, cond, detail = '') {
  if (cond) { passed++; results.push(`PASS  ${name}`); }
  else { failed++; results.push(`FAIL  ${name}${detail ? '  -> ' + detail : ''}`); }
}
const near = (a, b) => Math.abs(Number(a) - Number(b)) < 0.005;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function http(method, path, { token, body, form } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  let payload;
  if (form) payload = form;
  else if (body !== undefined) { headers['Content-Type'] = 'application/json'; payload = JSON.stringify(body); }
  let res;
  // The API rate-limits per IP (100/min); this suite runs far faster than an app does.
  for (let attempt = 0; ; attempt++) {
    res = await fetch(API + path, { method, headers, body: payload });
    if (res.status !== 429 || attempt >= 12) break;
    await sleep(5000);
  }
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* not json */ }
  return { status: res.status, json, text, headers: res.headers };
}
const data = (r) => r.json?.data ?? r.json?.Data;

const pw = () => 'T' + crypto.randomBytes(9).toString('base64url') + '9!a';
const phone = () => '010' + String(Math.floor(10_000_000 + Math.random() * 89_999_999));

// Valid tiny JPEG (1x1) for document uploads.
const JPEG = Buffer.from(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==',
  'base64');

async function registerDriver(name) {
  const p = phone(), password = pw();
  const r = await http('POST', 'Auth/phone-register-driver', {
    body: { phone: p, password, fullName: name, gender: 'Male', scooterType: 1, nationalId: '29001011234567' },
  });
  const d = data(r);
  if (!d?.token) throw new Error(`driver register failed ${r.status} ${r.text}`);
  return { id: d.userId, token: d.token, phone: p, password, name };
}
async function registerClient(name) {
  const p = phone(), password = pw();
  const r = await http('POST', 'Auth/phone-register', { body: { phone: p, password, fullName: name, gender: 'Male' } });
  const d = data(r);
  if (!d?.token) throw new Error(`client register failed ${r.status} ${r.text}`);
  return { id: d.userId, token: d.token, phone: p, password, name };
}

async function hub(path, token, events = {}) {
  const conn = new signalR.HubConnectionBuilder()
    .withUrl(`${BASE}/${path}`, { accessTokenFactory: () => token })
    .configureLogging(signalR.LogLevel.Error)
    .build();
  for (const [name, fn] of Object.entries(events)) conn.on(name, fn);
  for (let attempt = 0; ; attempt++) {
    try { await conn.start(); break; }
    catch (e) {
      if (!String(e).includes('429') || attempt >= 12) throw e;
      await sleep(5000);
    }
  }
  return conn;
}
const ok = (r) => (r?.isSuccess ?? r?.IsSuccess) === true;
const msg = (r) => r?.message ?? r?.Message;
const statusCode = (r) => r?.statusCode ?? r?.StatusCode;

// Full ride through the hubs. Fare = ceil(km * 5) + 5.
async function ride(client, driver, { km, method = 'Cash' }) {
  const c = await hub('tripHub', client.token);
  const req = await c.invoke('RequestTrip', {
    startLat: 30.05, startLng: 31.24, endLat: 30.07, endLng: 31.26,
    startAddress: 'A', endAddress: 'B', distance: km, userId: client.id, paymentMethod: method,
  });
  const reqData = req?.data ?? req?.Data;
  const tripId = reqData?.id ?? reqData?.Id;
  if (!tripId) { await c.stop(); throw new Error('RequestTrip failed: ' + JSON.stringify(req)); }
  const d = await hub('tripHub', driver.token);
  const dh = await hub('driverHub', driver.token);
  await dh.invoke('UpdateDriverStatus', { driverId: driver.id, isAvailable: true, latitude: 30.05, longitude: 31.24 });
  const steps = {};
  steps.accept = await d.invoke('ApproveAndAssignDriverToTrip', tripId, driver.id, '30.05', '31.24');
  if (ok(steps.accept)) {
    steps.arrived = await d.invoke('Arrived', tripId, driver.id);
    steps.start = await d.invoke('StartTrip', tripId, driver.id);
    steps.end = await d.invoke('EndTrip', tripId, driver.id);
  } else {
    await c.invoke('CancelTripRequest', tripId, client.id, 'test cleanup').catch(() => {});
  }
  await sleep(300);
  await Promise.all([c.stop(), d.stop(), dh.stop()]);
  return { tripId, steps };
}

// Paymob TRANSACTION webhook signed exactly like Paymob does (see PaymentService).
async function paymobWebhook(orderId, amountCents, { success = true, txId } = {}) {
  const obj = {
    id: txId ?? Math.floor(Math.random() * 1e9), pending: false, amount_cents: amountCents, success,
    is_auth: false, is_capture: false, is_standalone_payment: true, is_voided: false, is_refunded: false,
    is_3d_secure: true, integration_id: 1, profile_id: 1, order: { id: Number(orderId) },
    created_at: '2026-10-05T19:00:00.000000', currency: 'EGP', error_occured: false,
    has_parent_transaction: false, owner: 1, source_data: { pan: '2346', sub_type: 'MasterCard', type: 'card' },
  };
  const concat = `${obj.amount_cents}${obj.created_at}${obj.currency}${obj.error_occured}${obj.has_parent_transaction}${obj.id}` +
    `${obj.integration_id}${obj.is_3d_secure}${obj.is_auth}${obj.is_capture}${obj.is_refunded}${obj.is_standalone_payment}` +
    `${obj.is_voided}${obj.order.id}${obj.owner}${obj.pending}${obj.source_data.pan}${obj.source_data.sub_type}` +
    `${obj.source_data.type}${obj.success}`;
  const hmac = crypto.createHmac('sha512', process.env.HMAC).update(concat).digest('hex');
  return http('POST', `Payment/webhook?hmac=${hmac}`, { body: { type: 'TRANSACTION', obj } });
}

async function uploadDoc(driver, type, { expiry, bytes = JPEG, filename = 'doc.jpg' } = {}) {
  const form = new FormData();
  form.append('type', type);
  form.append('file', new Blob([bytes], { type: 'image/jpeg' }), filename);
  if (expiry) form.append('expiryDate', expiry);
  return http('POST', 'DriverVerification/me/documents', { token: driver.token, form });
}
const future = new Date(Date.now() + 400 * 864e5).toISOString().slice(0, 10);
const summary = async (driver) => data(await http('GET', 'DriverFinance/me/summary', { token: driver.token }));
const balance = async (driver) => (await summary(driver)).balance;
const ledger = async (driver, size = 50) =>
  data(await http('GET', `DriverFinance/me/ledger?pageNumber=1&pageSize=${size}`, { token: driver.token })).data;

// ---------------------------------------------------------------------------
async function setup() {
  const email = `admin-e2e-${Date.now()}@vgo.test`, password = pw();
  const seed = await http('POST', 'Auth/seed-admin', { body: { email, password } });
  check('seed admin on empty staging DB', seed.status === 200, seed.text);
  const login = await http('POST', 'Auth/login', { body: { email, password } });
  state.admin = { token: data(login)?.token, email, password };
  check('admin login', !!state.admin.token, login.text);

  const price = await http('POST', 'PricingRule', { token: state.admin.token, body: { pricePerKillo: 5 } });
  check('create pricing rule (5 EGP/km)', price.status === 201, price.text);

  state.oldDriver = await registerDriver('Captain Before Launch');
  save();
}

async function main() {
  const A = state.admin.token;

  // ---------- launch bootstrap ----------
  const oldV = data(await http('GET', 'DriverVerification/me', { token: state.oldDriver.token }));
  check('bootstrap: pre-launch captain grandfathered as Approved', oldV?.status === 'Approved', JSON.stringify(oldV));
  const graceDays = oldV?.documentsDeadline ? (new Date(oldV.documentsDeadline) - Date.now()) / 864e5 : 0;
  check('bootstrap: 7-day documents deadline set', graceDays > 6.9 && graceDays < 7.2, `days=${graceDays}`);
  check('bootstrap: grandfathered captain can go online', oldV?.canGoOnline === true, JSON.stringify(oldV));
  const settings0 = data(await http('GET', 'DriverFinance/admin/settings', { token: A }));
  check('bootstrap: ledgerStartAt set', !!settings0?.ledgerStartAt, JSON.stringify(settings0));
  check('defaults on new pricing row: limit 1000 / warning 80', settings0?.cashLimit === 1000 && settings0?.warningPercent === 80, JSON.stringify(settings0));

  // ---------- settings ----------
  const bad = await http('PUT', 'DriverFinance/admin/settings', { token: A, body: { companyCommissionPercent: 150, cashLimit: 100, warningPercent: 80 } });
  check('settings: commission > 100 rejected', bad.status === 400, bad.text);
  const put = await http('PUT', 'DriverFinance/admin/settings', { token: A, body: { companyCommissionPercent: 10, cashLimit: 100, warningPercent: 80 } });
  check('settings: commission 10% / limit 100 / warning 80 saved', put.status === 200 && data(put)?.companyCommissionPercent === 10, put.text);

  // ---------- KYC ----------
  const client = await registerClient('Rider One');
  const cap = await registerDriver('Captain New');
  state.client = client; state.cap = cap; save();

  let v = data(await http('GET', 'DriverVerification/me', { token: cap.token }));
  check('KYC: new captain starts PendingDocuments', v?.status === 'PendingDocuments', JSON.stringify(v));
  check('KYC: 5 required documents missing', v?.missingTypes?.length === 5, JSON.stringify(v?.missingTypes));
  let el = data(await http('GET', 'DriverFinance/me/eligibility', { token: cap.token }));
  check('KYC: new captain blocked with KYC_PENDING', el?.canGoOnline === false && el?.code === 'KYC_PENDING', JSON.stringify(el));

  // hub refuses going online and pushes the reason
  {
    let blocked = null;
    const dh = await hub('driverHub', cap.token, { DriverOnlineBlocked: (p) => { blocked = p; } });
    await dh.invoke('UpdateDriverStatus', { driverId: cap.id, isAvailable: true, latitude: 30.05, longitude: 31.24 });
    await sleep(500);
    await dh.stop();
    check('KYC: driverHub refuses going online + sends DriverOnlineBlocked', (blocked?.code ?? blocked?.Code) === 'KYC_PENDING', JSON.stringify(blocked));
  }
  // and accepting a trip is refused server-side
  {
    const r = await ride(client, cap, { km: 9 });
    check('KYC: unverified captain cannot accept a trip (403)', statusCode(r.steps.accept) === 403, JSON.stringify(r.steps.accept));
  }

  const txt = await uploadDoc(cap, 'NationalIdFront', { bytes: Buffer.from('not an image at all'), filename: 'x.jpg' });
  check('KYC: non-image upload rejected', txt.status === 400, txt.text);
  const noExp = await uploadDoc(cap, 'DriverLicense');
  check('KYC: licence without expiry rejected', noExp.status === 400, noExp.text);
  const pastExp = await uploadDoc(cap, 'DriverLicense', { expiry: '2020-01-01' });
  check('KYC: expired licence rejected', pastExp.status === 400, pastExp.text);
  const badType = await uploadDoc(cap, 'Passport');
  check('KYC: unknown document type rejected', badType.status === 400, badType.text);

  const selfie = await uploadDoc(cap, 'Selfie');
  check('KYC: selfie uploaded (public profile photo)', selfie.status === 200 && !!data(selfie)?.publicUrl, selfie.text);
  if (data(selfie)?.publicUrl) {
    const img = await fetch(data(selfie).publicUrl);
    check('KYC: selfie reachable at its public URL without auth', img.status === 200 && (img.headers.get('content-type') ?? '').startsWith('image/'), `${img.status} ${data(selfie).publicUrl}`);
    const me = data(await http('GET', 'DriverVerification/me', { token: cap.token }));
    check('KYC: selfie became the captain profile picture', me?.profilePicture === data(selfie).publicUrl, me?.profilePicture);
  }
  for (const t of ['NationalIdFront', 'NationalIdBack']) {
    const r = await uploadDoc(cap, t);
    check(`KYC: ${t} uploaded (private)`, r.status === 200 && data(r)?.publicUrl == null, r.text);
  }
  v = data(await http('GET', 'DriverVerification/me', { token: cap.token }));
  check('KYC: partial upload keeps PendingDocuments', v?.status === 'PendingDocuments', v?.status);
  for (const t of ['DriverLicense', 'VehicleLicense']) {
    const r = await uploadDoc(cap, t, { expiry: future });
    check(`KYC: ${t} uploaded with expiry`, r.status === 200 && !!data(r)?.expiryDate, r.text);
  }
  v = data(await http('GET', 'DriverVerification/me', { token: cap.token }));
  check('KYC: complete set -> UnderReview', v?.status === 'UnderReview', v?.status);
  el = data(await http('GET', 'DriverFinance/me/eligibility', { token: cap.token }));
  check('KYC: under review still blocked', el?.code === 'KYC_UNDER_REVIEW', JSON.stringify(el));

  const queue = data(await http('GET', 'DriverVerification/admin/queue?pageSize=50', { token: A }));
  check('KYC: captain appears in admin review queue', queue?.data?.some((q) => q.driverId === cap.id), JSON.stringify(queue));

  const adminView = data(await http('GET', `DriverVerification/admin/drivers/${cap.id}`, { token: A }));
  const idBack = adminView.documents.find((d) => d.type === 'NationalIdBack');
  const file = await http('GET', `DriverVerification/admin/documents/${idBack.id}/file`, { token: A });
  check('KYC: admin can stream a private document', file.status === 200 && (file.headers.get('content-type') ?? '').startsWith('image/jpeg'), `${file.status}`);
  check('KYC: private document not cacheable', (file.headers.get('cache-control') ?? '').includes('no-store'), file.headers.get('cache-control'));
  const capFile = await http('GET', `DriverVerification/admin/documents/${idBack.id}/file`, { token: cap.token });
  check('KYC: captain cannot use admin document endpoint', capFile.status === 403, `${capFile.status}`);
  const anonFile = await http('GET', `DriverVerification/admin/documents/${idBack.id}/file`);
  check('KYC: anonymous cannot read documents', anonFile.status === 401, `${anonFile.status}`);

  const noReason = await http('POST', `DriverVerification/admin/documents/${idBack.id}/review`, { token: A, body: { approve: false } });
  check('KYC: reject without reason refused', noReason.status === 400, noReason.text);
  await http('POST', `DriverVerification/admin/documents/${idBack.id}/review`, { token: A, body: { approve: false, reason: 'الصورة مش واضحة' } });
  v = data(await http('GET', 'DriverVerification/me', { token: cap.token }));
  check('KYC: rejected document -> captain Rejected with reason', v?.status === 'Rejected' && v?.note === 'الصورة مش واضحة', JSON.stringify(v?.status) + v?.note);
  check('KYC: rejected type listed as missing', v?.missingTypes?.includes('NationalIdBack'), JSON.stringify(v?.missingTypes));
  el = data(await http('GET', 'DriverFinance/me/eligibility', { token: cap.token }));
  check('KYC: rejected captain blocked (KYC_REJECTED)', el?.code === 'KYC_REJECTED', JSON.stringify(el));

  const premature = await http('POST', `DriverVerification/admin/drivers/${cap.id}/decision`, { token: A, body: { status: 'Approved' } });
  check('KYC: cannot approve captain with a rejected document', premature.status === 400, premature.text);

  await uploadDoc(cap, 'NationalIdBack');
  v = data(await http('GET', 'DriverVerification/me', { token: cap.token }));
  check('KYC: re-upload -> back to UnderReview', v?.status === 'UnderReview', v?.status);

  const docs = data(await http('GET', `DriverVerification/admin/drivers/${cap.id}`, { token: A })).documents;
  for (const d of docs) await http('POST', `DriverVerification/admin/documents/${d.id}/review`, { token: A, body: { approve: true } });
  v = data(await http('GET', 'DriverVerification/me', { token: cap.token }));
  check('KYC: approving every document approves the captain', v?.status === 'Approved' && v?.canGoOnline === true, JSON.stringify(v));

  const susp = await http('POST', `DriverVerification/admin/drivers/${cap.id}/decision`, { token: A, body: { status: 'Suspended', note: 'مخالفة' } });
  check('KYC: suspend captain', susp.status === 200, susp.text);
  el = data(await http('GET', 'DriverFinance/me/eligibility', { token: cap.token }));
  check('KYC: suspended captain blocked (SUSPENDED)', el?.code === 'SUSPENDED', JSON.stringify(el));
  const upSusp = await uploadDoc(cap, 'Selfie');
  check('KYC: suspended captain cannot upload', upSusp.status === 403, upSusp.text);
  await http('POST', `DriverVerification/admin/drivers/${cap.id}/decision`, { token: A, body: { status: 'Approved' } });
  el = data(await http('GET', 'DriverFinance/me/eligibility', { token: cap.token }));
  check('KYC: re-activated captain can go online', el?.canGoOnline === true, JSON.stringify(el));

  // ---------- ledger: cash trip ----------
  const t1 = await ride(client, cap, { km: 9 }); // fare 50
  check('trip1 (cash 50) completed through the hubs', ok(t1.steps.end), JSON.stringify(t1.steps));
  let s = await summary(cap);
  check('cash trip: captain owes 10% commission (-5)', near(s.balance, -5), `balance=${s.balance}`);
  check('summary today: 1 trip, gross 50, commission 5, net 45, cash 50',
    s.today.trips === 1 && near(s.today.grossFare, 50) && near(s.today.companyCommission, 5) && near(s.today.driverNet, 45) && near(s.today.cashCollected, 50),
    JSON.stringify(s.today));
  let l = await ledger(cap);
  check('ledger entry carries fare / % / commission / net',
    l[0]?.type === 'TripCashCommission' && near(l[0].tripFare, 50) && near(l[0].commissionPercent, 10) && near(l[0].driverNet, 45) && l[0].tripPaymentMethod === 'Cash',
    JSON.stringify(l[0]));

  // re-sync is idempotent (driver confirms cash -> triggers sync again)
  {
    const d = await hub('tripHub', cap.token);
    const r = await d.invoke('ConfirmCashPayment', t1.tripId);
    await d.stop();
    check('confirm cash payment accepted', ok(r), JSON.stringify(r));
  }
  check('re-sync does not double-post', near(await balance(cap), -5) && (await ledger(cap)).length === 1);

  // ---------- refused cash trip ----------
  const t2 = await ride(client, cap, { km: 9 });
  check('trip2 (cash) completed', ok(t2.steps.end), JSON.stringify(t2.steps));
  check('trip2 commission posted (-10 total)', near(await balance(cap), -10));
  {
    const d = await hub('tripHub', cap.token);
    const r = await d.invoke('ReportPaymentRefused', t2.tripId);
    await d.stop();
    check('captain reports rider refused to pay', ok(r), JSON.stringify(r));
  }
  l = await ledger(cap);
  check('refused cash trip: commission reversed by a correction', near(await balance(cap), -5) && l[0]?.type === 'TripCorrection' && near(l[0].amount, 5), JSON.stringify(l[0]));

  // the rider now owes that trip; he pays it online later -> captain gets his share
  {
    const intent = await http('POST', 'Payment/createIntent', { token: client.token, body: { userId: client.id, tripId: t2.tripId, price: 50, currency: 'EGP' } });
    const orderId = intent.json?.intention_order_id ?? intent.json?.intentionOrderId;
    check('rider debt: real Paymob intention created', !!orderId, intent.text.slice(0, 200));
    if (orderId) {
      const wh = await paymobWebhook(orderId, 5000);
      check('rider debt: signed webhook accepted', wh.status === 200, wh.text);
      l = await ledger(cap);
      check('refused trip later paid online -> captain credited +45', l[0]?.type === 'TripCardEarning' && near(l[0].amount, 45), JSON.stringify(l[0]));
      check('balance after debt payment = -5 + 45 = 40', near(await balance(cap), 40), String(await balance(cap)));
      state.cardOrder = { orderId, tripId: t2.tripId };
    }
  }
  const forged = await http('POST', 'Payment/webhook?hmac=deadbeef', { body: { type: 'TRANSACTION', obj: { id: 1, order: { id: 1 }, success: true, source_data: {} } } });
  check('forged webhook (bad HMAC) has no effect', forged.status === 200 && near(await balance(cap), 40));

  // ---------- commission change does not rewrite history ----------
  await http('PUT', 'DriverFinance/admin/settings', { token: A, body: { companyCommissionPercent: 20, cashLimit: 100, warningPercent: 80 } });
  if (state.cardOrder) await paymobWebhook(state.cardOrder.orderId, 5000); // replays -> re-sync of trip2
  check('commission change + webhook replay keeps old trip at 10%', near(await balance(cap), 40), String(await balance(cap)));
  const t3 = await ride(client, cap, { km: 9 }); // fare 50 @ 20% -> -10
  check('trip3 at the new 20% commission (-10)', ok(t3.steps.end) && near(await balance(cap), 30), String(await balance(cap)));
  await http('PUT', 'DriverFinance/admin/settings', { token: A, body: { companyCommissionPercent: 10, cashLimit: 100, warningPercent: 80 } });

  // ---------- payout account ----------
  const wrongPw = await http('PUT', 'DriverFinance/me/payout-account', { token: cap.token, body: { method: 'MobileWallet', account: '01012345678', accountName: 'Captain New', password: 'wrong' } });
  check('payout account: wrong password refused', wrongPw.status === 400, wrongPw.text);
  const badWallet = await http('PUT', 'DriverFinance/me/payout-account', { token: cap.token, body: { method: 'MobileWallet', account: '12345', accountName: 'Captain New', password: cap.password } });
  check('payout account: invalid wallet number refused', badWallet.status === 400, badWallet.text);
  const goodAcc = await http('PUT', 'DriverFinance/me/payout-account', { token: cap.token, body: { method: 'InstaPay', account: 'captain.new@instapay', accountName: 'Captain New', password: cap.password } });
  check('payout account: InstaPay address saved', goodAcc.status === 200, goodAcc.text);
  s = await summary(cap);
  check('summary shows payout account', s.payoutMethod === 'InstaPay' && s.payoutAccount === 'captain.new@instapay', JSON.stringify(s));

  // ---------- payout ----------
  const tooMuch = await http('POST', `DriverFinance/admin/drivers/${cap.id}/payouts`, { token: A, form: Object.assign(new FormData(), {}) });
  check('payout: missing amount/reference refused', tooMuch.status === 400, tooMuch.text);
  {
    const f = new FormData(); f.append('amount', '500'); f.append('reference', 'IP-123');
    const r = await http('POST', `DriverFinance/admin/drivers/${cap.id}/payouts`, { token: A, form: f });
    check('payout: more than the captain is owed refused', r.status === 400, r.text);
  }
  {
    const f = new FormData(); f.append('amount', '30'); f.append('reference', 'IP-REF-777'); f.append('note', 'تحويل أسبوعي');
    f.append('receipt', new Blob([JPEG], { type: 'image/jpeg' }), 'receipt.jpg');
    const r = await http('POST', `DriverFinance/admin/drivers/${cap.id}/payouts`, { token: A, form: f });
    check('payout: 30 EGP recorded with reference + receipt', r.status === 201, r.text);
    check('payout: balance back to 0', near(await balance(cap), 0));
    l = await ledger(cap);
    check('payout entry has reference + receipt link', l[0]?.type === 'Payout' && l[0].reference === 'IP-REF-777' && !!l[0].attachmentUrl, JSON.stringify(l[0]));
    const rec = await http('GET', l[0].attachmentUrl, { token: cap.token });
    check('captain can open his own payout receipt', rec.status === 200, `${rec.status}`);
    const other = await http('GET', l[0].attachmentUrl, { token: state.oldDriver.token });
    check('another captain cannot open the receipt', other.status === 403, `${other.status}`);
  }

  // ---------- adjustments ----------
  const noWhy = await http('POST', `DriverFinance/admin/drivers/${cap.id}/adjustments`, { token: A, body: { amount: -20 } });
  check('adjustment without reason refused', noWhy.status === 400, noWhy.text);
  await http('POST', `DriverFinance/admin/drivers/${cap.id}/adjustments`, { token: A, body: { amount: -20, reason: 'غرامة تأخير' } });
  check('penalty adjustment -20', near(await balance(cap), -20));
  await http('POST', `DriverFinance/admin/drivers/${cap.id}/adjustments`, { token: A, body: { amount: 20, reason: 'إلغاء الغرامة' } });
  check('bonus adjustment +20 -> 0', near(await balance(cap), 0));

  // ---------- cash limit lock ----------
  let blockedEvents = [];
  let financeEvents = 0;
  const watcher = await hub('tripHub', cap.token, {
    DriverOnlineBlocked: (p) => blockedEvents.push(p),
    DriverFinanceUpdated: () => { financeEvents++; },
  });
  const t4 = await ride(client, cap, { km: 99 }); // fare 500 -> -50
  check('trip4 (cash 500) -> -50, under the limit', ok(t4.steps.end) && near(await balance(cap), -50));
  el = data(await http('GET', 'DriverFinance/me/eligibility', { token: cap.token }));
  check('still allowed at 50% of the limit', el?.canGoOnline === true, JSON.stringify(el));
  const t5 = await ride(client, cap, { km: 99 }); // -> -100 = limit
  await sleep(800);
  check('trip5 -> debt 100 reaches the limit', ok(t5.steps.end) && near(await balance(cap), -100));
  el = data(await http('GET', 'DriverFinance/me/eligibility', { token: cap.token }));
  check('locked: CASH_LIMIT', el?.code === 'CASH_LIMIT', JSON.stringify(el));
  check('locked: DriverOnlineBlocked pushed after the trip', blockedEvents.some((p) => (p.code ?? p.Code) === 'CASH_LIMIT'), JSON.stringify(blockedEvents));
  check('DriverFinanceUpdated pushed on balance changes', financeEvents >= 2, `events=${financeEvents}`);
  s = await summary(cap);
  check('summary: isLocked + 100% used', s.isLocked === true && near(s.limitUsedPercent, 100), JSON.stringify({ l: s.isLocked, u: s.limitUsedPercent }));
  const t6 = await ride(client, cap, { km: 9 });
  check('locked captain cannot accept a trip (403)', statusCode(t6.steps.accept) === 403, JSON.stringify(t6.steps.accept));
  {
    let b = null;
    const dh = await hub('driverHub', cap.token, { DriverOnlineBlocked: (p) => { b = p; } });
    await dh.invoke('UpdateDriverStatus', { driverId: cap.id, isAvailable: true, latitude: 30.05, longitude: 31.24 });
    await sleep(400); await dh.stop();
    check('locked captain refused by driverHub (old app builds too)', (b?.code ?? b?.Code) === 'CASH_LIMIT', JSON.stringify(b));
  }
  const drivers = data(await http('GET', 'DriverFinance/admin/drivers?filter=locked&pageSize=50', { token: A }));
  check('admin: captain listed under "locked"', drivers?.data?.some((d) => d.driverId === cap.id && d.isLocked), JSON.stringify(drivers));
  const ov = data(await http('GET', 'DriverFinance/admin/overview', { token: A }));
  check('admin overview counts the locked captain', ov?.lockedDrivers >= 1 && ov?.totalOwedToCompany >= 100, JSON.stringify(ov));

  // ---------- settlement via Paymob ----------
  const settle = await http('POST', 'DriverFinance/me/settle', { token: cap.token });
  const sd = data(settle);
  check('settle: Paymob checkout created for exactly 100', settle.status === 200 && near(sd?.amount, 100) && sd?.checkoutUrl?.includes('clientSecret='), settle.text.slice(0, 300));
  if (sd?.paymentId) {
    let st = data(await http('GET', `DriverFinance/me/settle/${sd.paymentId}`, { token: cap.token }));
    check('settle: pending before payment, not credited', st?.status === 'Pending' && st?.credited === false, JSON.stringify(st));
    // the order id lives on the payment; fetch it via the admin settlements list
    const list = data(await http('GET', 'DriverFinance/admin/settlements?pageSize=50', { token: A }));
    check('admin: settlement listed', list?.data?.some((x) => x.paymentId === sd.paymentId), JSON.stringify(list));
    state.settlementPaymentId = sd.paymentId; save();
    console.log('NEED_ORDER_ID_FOR', sd.paymentId);
  }
  await watcher.stop();

  const other = await registerClient('Rider Two');
  const asClient = await http('GET', 'DriverFinance/me/summary', { token: other.token });
  check('authz: rider cannot read captain finance', asClient.status === 403, `${asClient.status}`);
  const asCap = await http('GET', 'DriverFinance/admin/overview', { token: cap.token });
  check('authz: captain cannot read admin finance', asCap.status === 403, `${asCap.status}`);
  const anon = await http('GET', 'DriverFinance/me/summary');
  check('authz: anonymous rejected', anon.status === 401, `${anon.status}`);

  const audit = data(await http('GET', `DriverFinance/admin/audit?targetUserId=${cap.id}&pageSize=100`, { token: A }));
  const actions = new Set((audit?.data ?? []).map((a) => a.action));
  for (const a of ['DocumentRejected', 'DocumentApproved', 'VerificationSuspended', 'VerificationApproved', 'PayoutRecorded', 'LedgerAdjustment', 'PayoutAccountChanged'])
    check(`audit log has ${a}`, actions.has(a), [...actions].join(','));
  save();
}

async function settle2() {
  // Runs after the shell looked up the Paymob order id of the settlement payment.
  const cap = state.cap, A = state.admin.token, orderId = process.env.ORDER_ID;
  const before = await balance(cap);
  const results5 = await Promise.all([1, 2, 3, 4, 5].map(() => paymobWebhook(orderId, 10000, { txId: 555001 })));
  check('settlement: 5 concurrent webhook deliveries accepted', results5.every((r) => r.status === 200));
  const after = await balance(cap);
  check('settlement credited exactly once (-100 -> 0)', near(before, -100) && near(after, 0), `before=${before} after=${after}`);
  const st = data(await http('GET', `DriverFinance/me/settle/${state.settlementPaymentId}`, { token: cap.token }));
  check('settlement status: Paid + credited + can go online', st?.status === 'Paid' && st?.credited && st?.canGoOnline, JSON.stringify(st));
  const el = data(await http('GET', 'DriverFinance/me/eligibility', { token: cap.token }));
  check('lock lifted after settlement', el?.canGoOnline === true, JSON.stringify(el));
  const t7 = await ride(state.client, cap, { km: 9 });
  check('captain works again after settling', ok(t7.steps.end), JSON.stringify(t7.steps.accept));
  const l = await ledger(cap);
  check('ledger has exactly one Settlement entry', l.filter((e) => e.type === 'Settlement').length === 1);
  const nothing = await http('POST', 'DriverFinance/me/settle', { token: state.oldDriver.token });
  check('settle with no debt refused', nothing.status === 400, nothing.text);
  const ov = data(await http('GET', 'DriverFinance/admin/overview', { token: A }));
  check('overview: settled this month >= 100', ov?.settledThisMonth >= 100, JSON.stringify(ov));
}

async function overdue() {
  const v = data(await http('GET', 'DriverVerification/me', { token: state.oldDriver.token }));
  const el = data(await http('GET', 'DriverFinance/me/eligibility', { token: state.oldDriver.token }));
  check('grace period over without documents -> DOCS_OVERDUE', el?.code === 'DOCS_OVERDUE', JSON.stringify(el) + ' ' + v?.documentsDeadline);
}

async function banners() {
  const A = state.admin.token;
  const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
  const form = (fields, img = JPEG, name = 'ad.jpg') => {
    const f = new FormData();
    for (const [k, v] of Object.entries(fields)) if (v !== undefined) f.append(k, String(v));
    if (img) f.append('image', new Blob([img]), name);
    return f;
  };
  const active = async () => data(await http('GET', 'HomeBanners/active'));
  const all = async () => data(await http('GET', 'HomeBanners/admin', { token: A }));

  const empty = await http('GET', 'HomeBanners/active');
  check('banners: app can read active banners without login', empty.status === 200 && Array.isArray(data(empty)), empty.text);

  let r = await http('POST', 'HomeBanners/admin', { token: A, form: form({ isActive: true }, null) });
  check('banners: image required', r.status === 400, r.text);
  r = await http('POST', 'HomeBanners/admin', { token: A, form: form({ linkUrl: 'javascript:alert(1)', isActive: true }) });
  check('banners: non-http link rejected', r.status === 400, r.text);
  r = await http('POST', 'HomeBanners/admin', { token: A, form: form({ isActive: true }, Buffer.from('not an image'), 'x.jpg') });
  check('banners: non-image file rejected', r.status === 400, r.text);
  r = await http('POST', 'HomeBanners/admin', { token: A, form: form({ isActive: true, startsAt: '2030-01-02T00:00', endsAt: '2030-01-01T00:00' }) });
  check('banners: end before start rejected', r.status === 400, r.text);

  const a = data(await http('POST', 'HomeBanners/admin', { token: A, form: form({ title: 'Ad A', linkUrl: 'example.com/promo', isActive: true }) }));
  check('banners: link normalised to https', a?.linkUrl === 'https://example.com/promo', JSON.stringify(a));
  const b = data(await http('POST', 'HomeBanners/admin', { token: A, form: form({ title: 'Ad B', isActive: true }, PNG, 'b.png') }));
  check('banners: banner without link allowed', !!b?.id && b.linkUrl == null, JSON.stringify(b));
  const hidden = data(await http('POST', 'HomeBanners/admin', { token: A, form: form({ title: 'Hidden', isActive: false }) }));
  const future = data(await http('POST', 'HomeBanners/admin', { token: A, form: form({ title: 'Future', isActive: true, startsAt: '2030-01-01T00:00' }) }));
  const expired = data(await http('POST', 'HomeBanners/admin', { token: A, form: form({ title: 'Expired', isActive: true, endsAt: '2020-01-01T00:00' }) }));
  check('banners: future/expired campaigns marked not live', future?.isLive === false && expired?.isLive === false && a?.isLive === true);

  let act = await active();
  check('banners: app sees only live banners, in order', act.length === 2 && act[0].id === a.id && act[1].id === b.id, JSON.stringify(act));
  const img = await fetch(act[0].imageUrl);
  check('banners: image served publicly from /media', img.status === 200 && (img.headers.get('content-type') ?? '').startsWith('image/'), `${img.status} ${act[0].imageUrl}`);

  const ids = (await all()).map((x) => x.id);
  const reordered = [b.id, a.id, ...ids.filter((x) => x !== a.id && x !== b.id)];
  r = await http('PUT', 'HomeBanners/admin/order', { token: A, body: reordered });
  act = await active();
  check('banners: reorder changes the carousel order', r.status === 200 && act[0].id === b.id && act[1].id === a.id, JSON.stringify(act));
  r = await http('PUT', 'HomeBanners/admin/order', { token: A, body: [a.id] });
  check('banners: partial reorder rejected', r.status === 400, r.text);

  const oldUrl = a.imageUrl;
  r = await http('PUT', `HomeBanners/admin/${a.id}`, { token: A, form: form({ title: 'Ad A2', linkUrl: '', isActive: true }, PNG, 'a2.png') });
  const a2 = data(r);
  check('banners: update replaces image and clears link', r.status === 200 && a2.imageUrl !== oldUrl && a2.linkUrl == null, r.text);
  check('banners: replaced image file removed', (await fetch(oldUrl)).status === 404);
  r = await http('PUT', `HomeBanners/admin/${hidden.id}`, { token: A, form: form({ title: 'Hidden', isActive: true }, null) });
  check('banners: enabling a hidden banner shows it (no new image needed)', r.status === 200 && (await active()).some((x) => x.id === hidden.id), r.text);

  for (let i = 0; i < 3; i++) await http('POST', `HomeBanners/${b.id}/click`);
  const bAfter = (await all()).find((x) => x.id === b.id);
  check('banners: taps are counted', bAfter?.clickCount === 3, JSON.stringify(bAfter));

  r = await http('DELETE', `HomeBanners/admin/${b.id}`, { token: A });
  check('banners: delete removes it from the app', r.status === 200 && !(await active()).some((x) => x.id === b.id), r.text);
  check('banners: deleted image file removed', (await fetch(b.imageUrl)).status === 404);

  const asClient = await http('GET', 'HomeBanners/admin', { token: state.client.token });
  check('banners: rider cannot manage banners', asClient.status === 403, `${asClient.status}`);
  const anon = await http('POST', 'HomeBanners/admin', { form: form({ isActive: true }) });
  check('banners: anonymous cannot create banners', anon.status === 401, `${anon.status}`);

  let created = (await all()).length;
  while (created < 10) { await http('POST', 'HomeBanners/admin', { token: A, form: form({ isActive: false }) }); created++; }
  r = await http('POST', 'HomeBanners/admin', { token: A, form: form({ isActive: true }) });
  check('banners: capped at 10 slots', r.status === 400, r.text);
  const audit = data(await http('GET', 'DriverFinance/admin/audit?pageSize=100', { token: A }));
  check('banners: changes are in the audit log', ['BannerCreated', 'BannerUpdated', 'BannerDeleted', 'BannersReordered'].every((x) => audit.data.some((e) => e.action === x)));
}

try {
  if (PHASE === 'setup') await setup();
  else if (PHASE === 'main') await main();
  else if (PHASE === 'settle') await settle2();
  else if (PHASE === 'overdue') await overdue();
  else if (PHASE === 'banners') await banners();
} catch (e) {
  failed++;
  results.push(`FAIL  crashed: ${e.stack ?? e}`);
}
console.log(results.join('\n'));
console.log(`\n${PHASE}: ${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
