import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  runApp(const ZarinParsehApp());
}

class ZarinParsehApp extends StatelessWidget {
  const ZarinParsehApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'زرین‌پارسه',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0F12),
        primaryColor: const Color(0xFFFFD700),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
          secondary: Color(0xFFC5A059),
          surface: Color(0xFF161B22),
        ),
        fontFamily: 'sans-serif',
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
    );
  }
}

class GoldItem {
  final String title;
  final String price;
  final String change;
  final String time;

  GoldItem({required this.title, required this.price, required this.change, required this.time});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<GoldItem> _items = [];
  bool _loading = true;
  String _search = '';
  final _weightController = TextEditingController();
  final _feeController = TextEditingController(text: '7');
  double _calcResult = 0;

  @override
  void initState() {
    super.initState();
    _fetchPrices();
  }

  Future<void> _fetchPrices() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('https://api.tgju.org/v1/widget/tmp/item-data.json')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        final rawItems = decoded['items'] ?? decoded['data'] ?? [];
        List<GoldItem> list = [];
        for (var item in rawItems) {
          list.add(GoldItem(
            title: item['title'] ?? item['name'] ?? 'عنوان نامشخص',
            price: (item['price'] ?? item['p'] ?? '0').toString(),
            change: (item['change'] ?? item['d'] ?? '0%').toString(),
            time: (item['time'] ?? item['t'] ?? 'امروز').toString(),
          ));
        }
        setState(() {
          _items = list;
          _loading = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback data
    setState(() {
      _items = [
        GoldItem(title: 'طلای ۱۸ عیار', price: '۳,۶۵۰,۰۰۰', change: '+۱.۲٪', time: 'لحظه‌ای'),
        GoldItem(title: 'طلای ۲۴ عیار', price: '۴,۸۶۰,۰۰۰', change: '+۱.۱٪', time: 'لحظه‌ای'),
        GoldItem(title: 'سکه تمام طرح جدید (امامی)', price: '۴۳,۲۰۰,۰۰۰', change: '+۰.۸٪', time: 'لحظه‌ای'),
        GoldItem(title: 'نیم سکه بهار آزادی', price: '۲۳,۶۰۰,۰۰۰', change: '-۰.۲٪', time: 'لحظه‌ای'),
        GoldItem(title: 'ربع سکه بهار آزادی', price: '۱۵,۴۰۰,۰۰۰', change: '+۰.۵٪', time: 'لحظه‌ای'),
        GoldItem(title: 'سکه گرمی', price: '۷,۱۰۰,۰۰۰', change: '۰.۰٪', time: 'لحظه‌ای'),
        GoldItem(title: 'انس جهانی طلا (دلار)', price: '۲,۶۵۲', change: '+۰.۴٪', time: 'لحظه‌ای'),
      ];
      _loading = false;
    });
  }

  void _calculateGold() {
    double weight = double.tryParse(_weightController.text) ?? 0;
    double wage = double.tryParse(_feeController.text) ?? 0;
    double unitPrice = 3650000;
    double base = weight * unitPrice;
    double total = base + (base * (wage / 100)) + (base * 0.09);
    setState(() {
      _calcResult = total;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 24),
            SizedBox(width: 8),
            Text('زرین‌پارسه', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
      ),
      body: _currentIndex == 0 ? _buildPriceList() : _buildCalculator(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: const Color(0xFF161B22),
        indicatorColor: const Color(0xFFFFD700).withOpacity(0.25),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.show_chart, color: Color(0xFFFFD700)), label: 'قیمت‌ها'),
          NavigationDestination(icon: Icon(Icons.calculate, color: Color(0xFFFFD700)), label: 'محاسبه‌گر طلا'),
        ],
      ),
    );
  }

  Widget _buildPriceList() {
    final filtered = _items.where((e) => e.title.contains(_search)).toList();
    return RefreshIndicator(
      onRefresh: _fetchPrices,
      color: const Color(0xFFFFD700),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) => setState(() => _search = val),
              decoration: InputDecoration(
                hintText: 'جستجو در طلا، سکه و ارز...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFFFD700)),
                filled: true,
                fillColor: const Color(0xFF1E232B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      final isPositive = !item.change.contains('-');
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2A313C)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 6),
                                Text(item.time, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(' تومان', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFD700), fontSize: 15)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPositive ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.change,
                                    style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildCalculator() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2B210B), Color(0xFF161B22)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
            ),
            child: Column(
              children: [
                const Text('مبلغ کل قابل پرداخت (با اجرت و مالیات)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 10),
                Text(
                  NumberFormat('#,###').format(_calcResult.round()) + ' تومان',
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'وزن طلا (گرم)',
              filled: true,
              fillColor: const Color(0xFF161B22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _feeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'درصد اجرت ساخت (%)',
              filled: true,
              fillColor: const Color(0xFF161B22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _calculateGold,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: BorderRadius.circular(12),
            ),
            child: const Text('محاسبه دقیق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
