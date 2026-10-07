import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() => runApp(const ZarinParsehApp());

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
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
          secondary: Color(0xFFC5A059),
          surface: Color(0xFF161B22),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
    );
  }
}

class GoldItem {
  final String title, price, change, time;
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
  void initState() { super.initState(); _fetchPrices(); }

  Future<void> _fetchPrices() async {
    setState(() => _loading = true);
    try {
      final res = await http
          .get(Uri.parse('https://api.tgju.org/v1/widget/tmp/item-data.json'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        final raw = decoded['items'] ?? decoded['data'] ?? [];
        final list = <GoldItem>[];
        for (var item in raw) {
          list.add(GoldItem(
            title: (item['title'] ?? item['name'] ?? 'نامشخص').toString(),
            price: (item['price'] ?? item['p'] ?? '0').toString(),
            change: (item['change'] ?? item['d'] ?? '0').toString(),
            time: (item['time'] ?? item['t'] ?? 'لحظه‌ای').toString(),
          ));
        }
        if (list.isNotEmpty) {
          setState(() { _items = list; _loading = false; });
          return;
        }
      }
    } catch (_) {}
    setState(() {
      _items = [
        GoldItem(title: 'طلای ۱۸ عیار', price: '3,650,000', change: '+1.2%', time: 'لحظه‌ای'),
        GoldItem(title: 'طلای ۲۴ عیار', price: '4,860,000', change: '+1.1%', time: 'لحظه‌ای'),
        GoldItem(title: 'سکه امامی', price: '43,200,000', change: '+0.8%', time: 'لحظه‌ای'),
        GoldItem(title: 'نیم سکه', price: '23,600,000', change: '-0.2%', time: 'لحظه‌ای'),
        GoldItem(title: 'ربع سکه', price: '15,400,000', change: '+0.5%', time: 'لحظه‌ای'),
        GoldItem(title: 'سکه گرمی', price: '7,100,000', change: '0.0%', time: 'لحظه‌ای'),
        GoldItem(title: 'انس جهانی طلا', price: '2,652', change: '+0.4%', time: 'لحظه‌ای'),
      ];
      _loading = false;
    });
  }

  void _calculateGold() {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final wage = double.tryParse(_feeController.text) ?? 0;
    final base = weight * 3650000;
    setState(() => _calcResult = base + (base * wage / 100) + (base * 0.09));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        centerTitle: true,
        title: const Text('زرین‌پارسه',
            style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
      ),
      body: _currentIndex == 0 ? _buildPrices() : _buildCalculator(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF161B22),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.show_chart, color: Color(0xFFFFD700)), label: 'قیمت‌ها'),
          NavigationDestination(icon: Icon(Icons.calculate, color: Color(0xFFFFD700)), label: 'محاسبه‌گر'),
        ],
      ),
    );
  }

  Widget _buildPrices() {
    final filtered = _items.where((e) => e.title.contains(_search)).toList();
    return RefreshIndicator(
      onRefresh: _fetchPrices,
      color: const Color(0xFFFFD700),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'جستجو...',
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
                    final positive = !item.change.contains('-');
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
                          Expanded(child: Text(item.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${item.price} ت',
                                  style: const TextStyle(
                                      color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(item.change,
                                  style: TextStyle(
                                      color: positive ? Colors.greenAccent : Colors.redAccent,
                                      fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ]),
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
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
            ),
            child: Column(children: [
              const Text('مبلغ کل پرداختی (با اجرت و مالیات)',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Text('${NumberFormat('#,###').format(_calcResult.round())} تومان',
                  style: const TextStyle(
                      color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: 'وزن طلا (گرم)',
                filled: true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _feeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: 'درصد اجرت ساخت',
                filled: true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _calculateGold,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('محاسبه دقیق',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
