import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const ZarinParsehApp());

const _gold = Color(0xFFB68118);
const _cacheKey = 'zarin_cache_v1';
const _settingsKey = 'zarin_settings_v1';

class ZarinParsehApp extends StatelessWidget {
  const ZarinParsehApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _gold,
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'زرین‌پارسه',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFFAF8F2),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  final Map<String, double> _prices = {};
  DateTime? _updatedAt;
  String? _error;
  bool _loading = false;
  bool _rial = false;
  Timer? _timer;

  final _url = TextEditingController();
  final _xauPath = TextEditingController(text: 'data.XAUUSD');
  final _gold18Path = TextEditingController(text: 'data.gold18');
  final _gold24Path = TextEditingController(text: 'data.gold24');
  final _headerName = TextEditingController();
  final _headerValue = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _url.dispose();
    _xauPath.dispose();
    _gold18Path.dispose();
    _gold24Path.dispose();
    _headerName.dispose();
    _headerValue.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    final settings = prefs.getString(_settingsKey);

    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        for (final key in ['xau', 'g18', 'g24']) {
          final value = data[key];
          if (value is num && value > 0) {
            _prices[key] = value.toDouble();
          }
        }
        final stamp = data['updatedAt'];
        if (stamp is String) {
          _updatedAt = DateTime.tryParse(stamp);
        }
      } catch (_) {}
    }

    if (settings != null) {
      try {
        final data = jsonDecode(settings) as Map<String, dynamic>;
        _url.text = data['url'] as String? ?? '';
        _xauPath.text = data['xauPath'] as String? ?? 'data.XAUUSD';
        _gold18Path.text = data['gold18Path'] as String? ?? 'data.gold18';
        _gold24Path.text = data['gold24Path'] as String? ?? 'data.gold24';
        _headerName.text = data['headerName'] as String? ?? '';
        _headerValue.text = data['headerValue'] as String? ?? '';
        _rial = data['rial'] as bool? ?? false;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {});
    _configureTimer();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _settingsKey,
      jsonEncode({
        'url': _url.text.trim(),
        'xauPath': _xauPath.text.trim(),
        'gold18Path': _gold18Path.text.trim(),
        'gold24Path': _gold24Path.text.trim(),
        'headerName': _headerName.text.trim(),
        'headerValue': _headerValue.text,
        'rial': _rial,
      }),
    );
    _configureTimer();
  }

  void _configureTimer() {
    _timer?.cancel();
    if (_url.text.trim().isNotEmpty) {
      _timer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => _fetchPrices(),
      );
    }
  }

  dynamic _atPath(dynamic root, String path) {
    dynamic current = root;
    for (final part
        in path.trim().split('.').where((p) => p.isNotEmpty)) {
      if (current is Map) {
        if (!current.containsKey(part)) return null;
        current = current[part];
      } else if (current is List) {
        final index = int.tryParse(part);
        if (index == null || index < 0 || index >= current.length) {
          return null;
        }
        current = current[index];
      } else {
        return null;
      }
    }
    return current;
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is! String) return null;

    var text = value.trim()
        .replaceAll('۰', '0').replaceAll('۱', '1')
        .replaceAll('۲', '2').replaceAll('۳', '3')
        .replaceAll('۴', '4').replaceAll('۵', '5')
        .replaceAll('۶', '6').replaceAll('۷', '7')
        .replaceAll('۸', '8').replaceAll('۹', '9')
        .replaceAll('٠', '0').replaceAll('١', '1')
        .replaceAll('٢', '2').replaceAll('٣', '3')
        .replaceAll('٤', '4').replaceAll('٥', '5')
        .replaceAll('٦', '6').replaceAll('٧', '7')
        .replaceAll('٨', '8').replaceAll('٩', '9')
        .replaceAll(',', '').replaceAll('٬', '')
        .replaceAll(' ', '');

    return double.tryParse(text);
  }

  Future<void> _fetchPrices() async {
    final endpoint = _url.text.trim();

    if (endpoint.isEmpty) {
      if (mounted) {
        setState(() => _error = 'ابتدا نشانی API را در تنظیمات وارد کنید.');
      }
      return;
    }

    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      if (mounted) setState(() => _error = 'نشانی API معتبر نیست.');
      return;
    }

    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final headers = <String, String>{'Accept': 'application/json'};

      if (_headerName.text.trim().isNotEmpty) {
        headers[_headerName.text.trim()] = _headerValue.text;
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('پاسخ سرور: ${response.statusCode}');
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final updates = <String, double>{};

      final paths = {
        'xau': _xauPath.text,
        'g18': _gold18Path.text,
        'g24': _gold24Path.text,
      };

      for (final entry in paths.entries) {
        final value = _number(_atPath(body, entry.value));
        if (value != null && value > 0 && value.isFinite) {
          updates[entry.key] =
              (entry.key != 'xau' && _rial) ? value / 10 : value;
        }
      }

      if (updates.isEmpty) {
        throw Exception('از مسیرهای تعیین‌شده قیمت معتبری پیدا نشد.');
      }

      _prices.addAll(updates);
      _updatedAt = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'xau': _prices['xau'],
          'g18': _prices['g18'],
          'g24': _prices['g24'],
          'updatedAt': _updatedAt!.toIso8601String(),
        }),
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _friendlyError(e);
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('TimeoutException')) {
      return 'مهلت پاسخ API تمام شد؛ دوباره تلاش کنید.';
    }
    if (message.contains('FormatException')) {
      return 'پاسخ API JSON معتبر نیست.';
    }
    return 'دریافت قیمت ناموفق بود: $message';
  }

  String _digits(String input) => input
      .replaceAll('0', '۰').replaceAll('1', '۱')
      .replaceAll('2', '۲').replaceAll('3', '۳')
      .replaceAll('4', '۴').replaceAll('5', '۵')
      .replaceAll('6', '۶').replaceAll('7', '۷')
      .replaceAll('8', '۸').replaceAll('9', '۹');

  String _format(double? value, {int decimals = 0}) {
    if (value == null || !value.isFinite) return '—';
    final fraction =
        decimals > 0 ? '.${List<String>.filled(decimals, '0').join()}' : '';
    final formatter = NumberFormat('#,##0$fraction', 'en_US');
    return _digits(formatter.format(value));
  }

  String _timeLabel() {
    if (_updatedAt == null) return 'هنوز قیمت موفقی دریافت نشده است';
    final time =
        DateFormat('yyyy/MM/dd  HH:mm', 'en_US').format(_updatedAt!.toLocal());
    return 'آخرین دریافت موفق: ${_digits(time)}';
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _marketPage(),
      CalculatorPage(prices: _prices, format: _format),
      _settingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'زرین‌پارسه',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          if (_tab == 0)
            IconButton(
              onPressed: _loading ? null : _fetchPrices,
              tooltip: 'به‌روزرسانی',
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'بازار',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            label: 'محاسبه‌گر',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune),
            label: 'تنظیم API',
          ),
        ],
      ),
    );
  }

  Widget _marketPage() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF342719), Color(0xFF78551D)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFFFD778),
                  size: 30,
                ),
                SizedBox(height: 14),
                Text(
                  'درخشش ریشه‌دار ایرانی',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'زرین‌پارسه؛ همراه آگاهانه شما در بازار طلا',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.circle, size: 9, color: Colors.blueGrey),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _url.text.trim().isEmpty
                      ? 'قیمت‌ها در دسترس نیستند؛ API تنظیم نشده'
                      : (_error ??
                          (_loading
                              ? 'در حال دریافت قیمت‌ها…'
                              : 'وضعیت: قیمت کش‌شده')),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: _loading ? null : _fetchPrices,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('تازه‌سازی'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _priceCard(
            'اونس جهانی طلا',
            'XAU / USD',
            _prices['xau'],
            'دلار / اونس تروا',
            Icons.public,
          ),
          const SizedBox(height: 11),
          _priceCard(
            'طلای ۱۸ عیار',
            'هر گرم',
            _prices['g18'],
            'تومان / گرم',
            Icons.diamond_outlined,
          ),
          const SizedBox(height: 11),
          _priceCard(
            'طلای ۲۴ عیار',
            'هر گرم',
            _prices['g24'],
            'تومان / گرم',
            Icons.diamond,
          ),
          const SizedBox(height: 16),
          Text(_timeLabel(), style: Theme.of(context).textTheme.bodySmall),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          if (_updatedAt != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'قیمت‌ها از آخرین دریافت موفق ذخیره شده‌اند و ممکن است کهنه باشند.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
        ],
      );

  Widget _priceCard(
    String title,
    String subtitle,
    double? value,
    String unit,
    IconData icon,
  ) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 16,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFFFF4D7),
                foregroundColor: _gold,
                child: Icon(icon),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _format(value),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    value == null ? 'ناموجود' : unit,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _settingsPage() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'اتصال به منبع قیمت',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 7),
          const Text(
            'نشانی خالی است تا زمانی که سرویس مورد اعتماد خود را انتخاب کنید. بدون API، قیمت زنده نمایش داده نمی‌شود.',
          ),
          const SizedBox(height: 18),
          _field(
            _url,
            'نشانی API',
            hint: 'https://example.com/api/prices',
            keyboard: TextInputType.url,
          ),
          const SizedBox(height: 14),
          _field(
            _xauPath,
            'مسیر JSON اونس (XAU/USD)',
            hint: 'data.XAUUSD',
          ),
          const SizedBox(height: 12),
          _field(
            _gold18Path,
            'مسیر JSON طلای ۱۸ عیار',
            hint: 'data.gold18',
          ),
          const SizedBox(height: 12),
          _field(
            _gold24Path,
            'مسیر JSON طلای ۲۴ عیار',
            hint: 'data.gold24',
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _rial,
            onChanged: (value) async {
              setState(() => _rial = value);
              await _saveSettings();
            },
            title: const Text('مقادیر ایران به ریال هستند'),
            subtitle: const Text(
              'در صورت فعال‌بودن، قیمت‌های ۱۸ و ۲۴ عیار برای نمایش به تومان تقسیم بر ۱۰ می‌شوند.',
            ),
          ),
          const SizedBox(height: 8),
          _field(
            _headerName,
            'نام هدر دلخواه (اختیاری)',
            hint: 'Authorization',
          ),
          const SizedBox(height: 12),
          _field(
            _headerValue,
            'مقدار هدر دلخواه (اختیاری)',
            hint: 'Bearer …',
            obscure: true,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await _saveSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تنظیمات ذخیره شد')),
                );
              }
              if (_url.text.trim().isNotEmpty) _fetchPrices();
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('ذخیره تنظیمات'),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'مسیرها با نقطه جدا می‌شوند و اندیس آرایه هم پشتیبانی می‌شود؛ مثل data.prices.0.value. پاسخ باید JSON باشد. یک جفت هدر دلخواه برای کلید API قابل تنظیم است.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType? keyboard,
    bool obscure = false,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: true,
        ),
      );
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({
    super.key,
    required this.prices,
    required this.format,
  });

  final Map<String, double> prices;
  final String Function(double?, {int decimals}) format;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final _weight = TextEditingController(text: '1');
  final _overridePrice = TextEditingController();
  final _workmanship = TextEditingController(text: '7');
  final _margin = TextEditingController(text: '0');
  final _tax = TextEditingController(text: '0');

  int _karat = 18;

  @override
  void dispose() {
    _weight.dispose();
    _overridePrice.dispose();
    _workmanship.dispose();
    _margin.dispose();
    _tax.dispose();
    super.dispose();
  }

  double _val(TextEditingController c) {
    final text = c.text.trim().replaceAll(',', '').replaceAll('٫', '.');
    return double.tryParse(text) ?? 0;
  }

  String _digits(String input) => input
      .replaceAll('0', '۰').replaceAll('1', '۱')
      .replaceAll('2', '۲').replaceAll('3', '۳')
      .replaceAll('4', '۴').replaceAll('5', '۵')
      .replaceAll('6', '۶').replaceAll('7', '۷')
      .replaceAll('8', '۸').replaceAll('9', '۹');

  @override
  Widget build(BuildContext context) {
    final key = _karat == 18 ? 'g18' : 'g24';
    final cached = widget.prices[key];
    final override = _val(_overridePrice);
    final unitPrice = override > 0 ? override : cached;
    final weight = _val(_weight);
    final base = (unitPrice ?? 0) * weight;
    final workmanship = base * _val(_workmanship) / 100;
    final margin = (base + workmanship) * _val(_margin) / 100;
    final tax = (workmanship + margin) * _val(_tax) / 100;
    final total = base + workmanship + margin + tax;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'برآورد ارزش طلا',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        const Text(
          'محاسبه‌گر تقریبی است؛ جزئیات نهایی را از فروشنده استعلام کنید.',
        ),
        const SizedBox(height: 18),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 18, label: Text('۱۸ عیار')),
            ButtonSegment(value: 24, label: Text('۲۴ عیار')),
          ],
          selected: {_karat},
          onSelectionChanged: (selection) =>
              setState(() => _karat = selection.first),
        ),
        const SizedBox(height: 14),
        _calcField(
          _weight,
          'وزن (گرم)',
          'مثلاً ۱٫۵',
          decimal: true,
        ),
        const SizedBox(height: 12),
        _calcField(
          _overridePrice,
          'قیمت دستی هر گرم (تومان، اختیاری)',
          cached == null
              ? 'قیمت کش‌شده موجود نیست؛ وارد کنید'
              : 'خالی = ${widget.format(cached)} تومان',
          decimal: true,
        ),
        const SizedBox(height: 12),
        _calcField(
          _workmanship,
          'اجرت ساخت (درصد)',
          '۷',
          decimal: true,
        ),
        const SizedBox(height: 12),
        _calcField(
          _margin,
          'سود فروشنده (درصد)',
          '۰',
          decimal: true,
        ),
        const SizedBox(height: 12),
        _calcField(
          _tax,
          'درصد مالیات (فرض کاربر)',
          '۰',
          decimal: true,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _line(
                  'قیمت مبنا ($_karat عیار)',
                  unitPrice == null
                      ? 'ناموجود — قیمت دستی وارد کنید'
                      : '${widget.format(unitPrice)} تومان / گرم',
                ),
                _line(
                  'ارزش وزن طلا',
                  '${widget.format(base)} تومان',
                ),
                _line(
                  'اجرت ساخت',
                  '${widget.format(workmanship)} تومان',
                ),
                _line(
                  'سود فروشنده',
                  '${widget.format(margin)} تومان',
                ),
                _line(
                  'مالیات بر اجرت و سود',
                  '${widget.format(tax)} تومان',
                ),
                const Divider(height: 24),
                _line(
                  'جمع برآوردی',
                  '${widget.format(total)} تومان',
                  bold: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'این خروجی صرفاً تخمینی است و دقت مالیاتی یا حقوقی ندارد. نرخ‌ها و نحوه محاسبه مالیات را با فروشنده و مقررات جاری بررسی کنید.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _calcField(
    TextEditingController controller,
    String label,
    String hint, {
    bool decimal = false,
  }) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
      );

  Widget _line(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _digits(value),
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
}
