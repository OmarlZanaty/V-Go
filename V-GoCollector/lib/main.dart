import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// V-Go Collector: runs on the company phone that holds the wallet SIMs
/// (Vodafone Cash / Etisalat Cash). It relays the "money received" SMS to the
/// V-Go server, which matches them with the captains' transfer requests.
/// The relaying itself is native (foreground service + WorkManager + SMS
/// receiver); these screens only pair the phone and show its health.
void main() => runApp(const CollectorApp());

const _yellow = Color(0xFFDCE01E);
const _black = Color(0xFF030407);
const _card = Color(0xFF252525);
const _green = Color(0xFF2ECC71);
const _red = Color(0xFFE74C3C);
const _orange = Color(0xFFFE7600);

const _native = MethodChannel('vgo.collector/native');

class CollectorApp extends StatelessWidget {
  const CollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V-Go تحصيل',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _black,
        colorScheme: const ColorScheme.dark(primary: _yellow, surface: _card),
        appBarTheme: const AppBarTheme(backgroundColor: _black, centerTitle: true),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _yellow,
            foregroundColor: _black,
            minimumSize: const Size.fromHeight(50),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class Status {
  Status(this.raw);
  final Map<String, dynamic> raw;

  bool get paired => raw['paired'] == true;
  bool get enabled => raw['enabled'] == true;
  String get baseUrl => raw['baseUrl']?.toString() ?? '';
  String get deviceName => raw['deviceName']?.toString() ?? '';
  DateTime? _at(String k) {
    final v = raw[k];
    return v is int && v > 0 ? DateTime.fromMillisecondsSinceEpoch(v) : null;
  }

  DateTime? get lastSweepAt => _at('lastSweepAt');
  DateTime? get lastHeartbeatAt => _at('lastHeartbeatAt');
  bool get lastHeartbeatOk => raw['lastHeartbeatOk'] == true;
  String? get lastError => raw['lastError']?.toString();
  int get pending => (raw['pending'] as num?)?.toInt() ?? 0;
  int get sentTotal => (raw['sentTotal'] as num?)?.toInt() ?? 0;
  bool get smsPermission => raw['smsPermission'] == true;
  bool get notificationAccess => raw['notificationAccess'] == true;
  bool get ignoringBattery => raw['ignoringBattery'] == true;
  String get manufacturer => raw['manufacturer']?.toString() ?? '';
  int get sdk => (raw['sdk'] as num?)?.toInt() ?? 0;
  String get appVersion => raw['appVersion']?.toString() ?? '';

  List<Map<String, dynamic>> _json(String k) {
    try {
      return (jsonDecode(raw[k]?.toString() ?? '[]') as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<Map<String, dynamic>> get wallets => _json('wallets');
  List<Map<String, dynamic>> get log => _json('log');

  /// Healthy = reported to the server within the last 3 minutes without error.
  bool get healthy =>
      lastHeartbeatOk &&
      lastHeartbeatAt != null &&
      DateTime.now().difference(lastHeartbeatAt!) < const Duration(minutes: 3);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Status? _status;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _native.invokeMethod('startService');
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system settings: permissions may have changed.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final raw = await _native.invokeMapMethod<String, dynamic>('status');
    if (mounted && raw != null) setState(() => _status = Status(raw));
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('V-Go تحصيل', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: s == null
            ? const Center(child: CircularProgressIndicator(color: _yellow))
            : s.paired
            ? StatusView(status: s, onChanged: _refresh)
            : PairView(status: s, onPaired: _refresh),
      ),
    );
  }
}

// ---------------------------------------------------------------- pairing

class PairView extends StatefulWidget {
  const PairView({super.key, required this.status, required this.onPaired});
  final Status status;
  final VoidCallback onPaired;

  @override
  State<PairView> createState() => _PairViewState();
}

class _PairViewState extends State<PairView> {
  late final _url = TextEditingController(text: widget.status.baseUrl);
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _pair() async {
    var url = _url.text.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    if (_code.text.trim().length < 6) {
      setState(() => _error = 'اكتب كود الربط اللي ظاهر في لوحة التحكم');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await _native.invokeMethod<String>('pair', {
      'baseUrl': url,
      'code': _code.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) widget.onPaired();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      children: [
        const Icon(Icons.sms_outlined, size: 56, color: _yellow),
        const SizedBox(height: 12),
        const Text(
          'ربط موبايل التحصيل',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'من لوحة التحكم ← التحصيل اليومي ← المحافظ وموبايل التحصيل ← إضافة موبايل، هيظهر كود من 8 حروف. اكتبه هنا.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'عنوان السيرفر'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(labelText: 'كود الربط'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _red)),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _busy ? null : _pair,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _black),
                )
              : const Text('ربط'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- status

class StatusView extends StatefulWidget {
  const StatusView({super.key, required this.status, required this.onChanged});
  final Status status;
  final VoidCallback onChanged;

  @override
  State<StatusView> createState() => _StatusViewState();
}

class _StatusViewState extends State<StatusView> {
  bool _syncing = false;
  bool _smsBlocked = false;

  Status get s => widget.status;

  Future<void> _askSms() async {
    final result = await Permission.sms.request();
    await Permission.notification.request();
    // A side-loaded app on Android 13+ gets "restricted setting" instead of a dialog.
    setState(() => _smsBlocked = !result.isGranted);
    await _native.invokeMethod('startService');
    widget.onChanged();
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final sent = await _native.invokeMethod('syncNow');
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(sent is int ? 'اتبعت $sent رسالة جديدة' : '$sent')),
    );
    widget.onChanged();
  }

  Future<void> _unpair() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('فك الربط؟'),
        content: const Text('الموبايل هيبطل يبعت رسايل الاستلام لحد ما تربطه تاني بكود جديد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('فك الربط', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _native.invokeMethod('unpair');
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = !s.enabled
        ? Colors.grey
        : s.healthy && s.smsPermission && s.lastError == null
        ? _green
        : s.healthy
        ? _orange
        : _red;
    final headline = !s.enabled
        ? 'متوقف'
        : !s.smsPermission
        ? 'محتاج صلاحية الرسايل'
        : s.healthy
        ? (s.lastError == null ? 'شغال ومتصل' : 'متصل بس فيه مشكلة')
        : 'مش متصل بالسيرفر';

    return RefreshIndicator(
      onRefresh: () async => widget.onChanged(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Box(
            border: color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 14, color: color),
                    const SizedBox(width: 8),
                    Text(headline, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                    const Spacer(),
                    Switch(
                      value: s.enabled,
                      activeThumbColor: _yellow,
                      onChanged: (v) async {
                        await _native.invokeMethod('setEnabled', {'enabled': v});
                        widget.onChanged();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _kv('الموبايل', s.deviceName.isEmpty ? '—' : s.deviceName),
                _kv('السيرفر', s.baseUrl),
                _kv('آخر اتصال بالسيرفر', _ago(s.lastHeartbeatAt)),
                _kv('آخر قراءة للرسايل', _ago(s.lastSweepAt)),
                _kv('رسايل اتبعتت', '${s.sentTotal}'),
                if (s.pending > 0) _kv('مستنية الإرسال', '${s.pending}', color: _orange),
                if (s.lastError != null) ...[
                  const SizedBox(height: 6),
                  Text(s.lastError!, style: const TextStyle(color: _red)),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _syncing ? null : _syncNow,
                  icon: _syncing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  label: const Text('ابعت دلوقتي'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (s.wallets.isNotEmpty)
            _Box(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المحافظ على الموبايل ده', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...s.wallets.map((w) => Text(
                        '${switch (w['provider']) {
                          'VodafoneCash' => 'فودافون كاش',
                          'EtisalatCash' => 'اتصالات كاش',
                          _ => 'انستاباي',
                        }}  ${w['phoneNumber']}',
                        textDirection: TextDirection.rtl,
                      )),
                ],
              ),
            )
          else
            const _Box(
              border: _orange,
              child: Text('مفيش محافظ متربوطة بالموبايل ده. من لوحة التحكم عدّل المحفظة واختار الموبايل ده.'),
            ),
          const SizedBox(height: 12),
          _Checklist(
            status: s,
            smsBlocked: _smsBlocked,
            onAskSms: _askSms,
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('آخر الرسايل اللي اتبعتت', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (s.log.isEmpty)
            const Text('لسه مفيش.', style: TextStyle(color: Colors.grey))
          else
            ...s.log.map((e) => _LogTile(entry: e)),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _unpair,
            child: const Text('فك ربط الموبايل', style: TextStyle(color: _red)),
          ),
          Center(
            child: Text('نسخة ${s.appVersion}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.status, required this.smsBlocked, required this.onAskSms});
  final Status status;
  final bool smsBlocked;
  final VoidCallback onAskSms;

  @override
  Widget build(BuildContext context) {
    final m = status.manufacturer.toLowerCase();
    final aggressive = ['xiaomi', 'redmi', 'poco', 'oppo', 'realme', 'vivo', 'huawei', 'honor', 'oneplus', 'infinix', 'tecno']
        .any(m.contains);
    return _Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('علشان يفضل شغال 24 ساعة', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _Step(
            done: status.smsPermission,
            title: 'صلاحية قراءة الرسايل',
            action: status.smsPermission ? null : ('اسمح', onAskSms),
          ),
          if (!status.smsPermission && (smsBlocked || status.sdk >= 33))
            const Padding(
              padding: EdgeInsets.only(right: 34, bottom: 8),
              child: Text(
                'لو الزرار مقفول أو ظهر "Restricted setting": الإعدادات ← التطبيقات ← V-Go تحصيل ← ⋮ (فوق) ← Allow restricted settings، وبعدين ارجع واضغط "اسمح" تاني.',
                style: TextStyle(color: _orange, fontSize: 13),
              ),
            ),
          if (!status.smsPermission)
            Padding(
              padding: const EdgeInsets.only(right: 26),
              child: TextButton(
                onPressed: () => _native.invokeMethod('openAppSettings'),
                child: const Text('افتح إعدادات التطبيق'),
              ),
            ),
          _Step(
            done: status.notificationAccess,
            title: 'قراءة إشعارات انستاباي',
            action: status.notificationAccess
                ? null
                : ('افتح', () => _native.invokeMethod('openNotificationAccess')),
          ),
          if (!status.notificationAccess)
            const Padding(
              padding: EdgeInsets.only(right: 34, bottom: 8),
              child: Text(
                'فعّل "V-Go تحصيل" في Notification access. لو مقفول: الإعدادات ← التطبيقات ← V-Go تحصيل ← ⋮ ← Allow restricted settings، وارجع فعّله. لازم تطبيق InstaPay (أو تطبيق البنك) يكون متسجّل عليه حساب الشركة والإشعارات شغالة.',
                style: TextStyle(color: _orange, fontSize: 13),
              ),
            ),
          _Step(
            done: status.ignoringBattery,
            title: 'إيقاف توفير البطارية للتطبيق',
            action: status.ignoringBattery
                ? null
                : ('افتح', () => _native.invokeMethod('requestBatteryExemption')),
          ),
          if (aggressive)
            _Step(
              done: null,
              title: 'التشغيل التلقائي (Autostart) + Battery saver: No restrictions',
              action: ('افتح', () => _native.invokeMethod('openAutostart')),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'خلي الموبايل على الشاحن ومتصل بالنت دايماً، وما تقفلش التطبيق من قايمة التطبيقات المفتوحة.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.done, required this.title, this.action});
  final bool? done; // null = can't be checked automatically
  final String title;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            done == true ? Icons.check_circle : done == false ? Icons.error_outline : Icons.help_outline,
            color: done == true ? _green : done == false ? _red : _orange,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
          if (action != null) TextButton(onPressed: action!.$2, child: Text(action!.$1)),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final match = entry['match']?.toString() ?? '';
    final (label, color) = switch (match) {
      'Matched' => ('اتطابق مع كابتن ✅', _green),
      'Unclaimed' => ('مستني طلب الكابتن', _orange),
      'NeedsReview' => ('محتاج مراجعة', _orange),
      'NotApplicable' => ('مش تحويل وارد', Colors.grey),
      _ => (match, Colors.grey),
    };
    final at = entry['receivedAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(entry['receivedAt'] as int)
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(entry['sender']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(entry['preview']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          if (at != null)
            Text(_time(at), style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.child, this.border});
  final Widget child;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: border == null ? null : Border.all(color: border!.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}

Widget _kv(String k, String v, {Color? color}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2),
  child: Row(
    children: [
      Text(k, style: const TextStyle(color: Colors.grey)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(v, textAlign: TextAlign.left, style: TextStyle(color: color), overflow: TextOverflow.ellipsis),
      ),
    ],
  ),
);

String _two(int v) => v.toString().padLeft(2, '0');
String _time(DateTime t) => '${_two(t.day)}/${_two(t.month)} ${_two(t.hour)}:${_two(t.minute)}';

String _ago(DateTime? t) {
  if (t == null) return 'لسه';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'من ${d.inSeconds} ثانية';
  if (d.inMinutes < 60) return 'من ${d.inMinutes} دقيقة';
  return _time(t);
}
