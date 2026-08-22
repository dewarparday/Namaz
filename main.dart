import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const PrayerTasksApp());

class PrayerTasksApp extends StatelessWidget {
  const PrayerTasksApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prayer Tasks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      home: const HomePage(),
    );
  }
}

class Prayer {
  final String name;
  final IconData icon;
  const Prayer(this.name, this.icon);
}

const prayers = [
  Prayer('Fajr', Icons.wb_twilight),
  Prayer('Zuhr', Icons.wb_sunny_outlined),
  Prayer('Asr', Icons.sunny),
  Prayer('Maghrib', Icons.nights_stay_outlined),
  Prayer('Isha', Icons.dark_mode_outlined),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Map<String, bool> done = {};
  final Map<String, int> qaza = {for (final p in prayers) p.name: 0};
  DateTime selected = DateTime.now();
  int tab = 0;

  String get keyDate => DateFormat('yyyy-MM-dd').format(selected);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('prayer_data');
    if (raw != null) {
      final all = jsonDecode(raw) as Map<String, dynamic>;
      final d = all[keyDate];
      if (d is Map) {
        done.clear();
        for (final p in prayers) done[p.name] = d[p.name] == true;
      }
    }
    final q = sp.getString('qaza_data');
    if (q != null) {
      final m = jsonDecode(q) as Map<String, dynamic>;
      for (final p in prayers) qaza[p.name] = (m[p.name] ?? 0) as int;
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('prayer_data');
    final all = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw));
    all[keyDate] = {for (final p in prayers) p.name: done[p.name] == true};
    await sp.setString('prayer_data', jsonEncode(all));
    await sp.setString('qaza_data', jsonEncode(qaza));
  }

  void _toggle(String name) {
    setState(() => done[name] = !(done[name] ?? false));
    _save();
  }

  int get completed => prayers.where((p) => done[p.name] == true).length;
  int get percent => ((completed / prayers.length) * 100).round();

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: selected,
    );
    if (d != null) {
      setState(() => selected = d);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _pickDate, icon: const Icon(Icons.calendar_month)),
        ],
      ),
      body: tab == 0 ? _dashboard() : tab == 1 ? _history() : _qaza(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.calendar_view_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'History'),
          NavigationDestination(icon: Icon(Icons.repeat), selectedIcon: Icon(Icons.repeat), label: 'Qaza'),
        ],
      ),
    );
  }

  Widget _dashboard() {
    final title = DateUtils.isSameDay(selected, DateTime.now())
        ? 'Today'
        : DateFormat('dd MMM yyyy').format(selected);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                SizedBox(
                  width: 120, height: 120,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                      value: completed / prayers.length,
                      strokeWidth: 10,
                    ),
                    Text('$percent%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 10),
                Text('$completed of ${prayers.length} prayers completed'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...prayers.map((p) => Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(p.icon)),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(done[p.name] == true ? 'Completed' : 'Pending'),
            trailing: Switch(
              value: done[p.name] == true,
              onChanged: (_) => _toggle(p.name),
            ),
            onTap: () => _toggle(p.name),
          ),
        )),
      ],
    );
  }

  Widget _history() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _readAll(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final all = snap.data!;
        final dates = all.keys.toList()..sort((a,b) => b.compareTo(a));
        if (dates.isEmpty) {
          return const Center(child: Text('No prayer history yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: dates.length,
          itemBuilder: (_, i) {
            final d = dates[i];
            final m = Map<String, dynamic>.from(all[d]);
            final c = prayers.where((p) => m[p.name] == true).length;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('dd MMM yyyy').format(DateTime.parse(d))),
                subtitle: Text('$c / 5 completed'),
                trailing: Text('${(c * 20)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _readAll() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('prayer_data');
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw));
  }

  Widget _qaza() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Qaza Prayer Tracker', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Keep a simple offline count of missed prayers.'),
        const SizedBox(height: 16),
        ...prayers.map((p) => Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(p.icon)),
            title: Text(p.name),
            subtitle: Text('${qaza[p.name]} Qaza remaining'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    if ((qaza[p.name] ?? 0) > 0) setState(() => qaza[p.name] = qaza[p.name]! - 1);
                    _save();
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => qaza[p.name] = (qaza[p.name] ?? 0) + 1);
                    _save();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}
