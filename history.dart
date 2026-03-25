import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard

import 'tire_model.dart'; // Tire class

// ===== Brand constants =====
const double kPad = 12.0;
const Color kKFUPMGreen = Color(0xFF008540); // background, icons
const Color kKFUPMGold  = Color(0xFFDAC961); // cards
const Color kNavGrey    = Color(0xFF424242); // buttons (white text)

// ---------- Event snapshot (saved inside a session) ----------
class EventSnapshot {
  EventSnapshot({
    required this.type,   // 'hardBrake' | 'sharpTurn' | 'overspeed'
    required this.value,  // m/s², g, or % overspeed
    required this.penalty,
    required this.time,
  });

  final String type;
  final double value;
  final double penalty;
  final DateTime time;

  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    'penalty': penalty,
    'time': time.toIso8601String(),
  };

  factory EventSnapshot.fromAny(dynamic e) {
    final typeName = e.type.toString();
    final simple = typeName.contains('.') ? typeName.split('.').last : typeName;
    return EventSnapshot(
      type: simple,
      value: (e.value as num).toDouble(),
      penalty: (e.penalty as num).toDouble(),
      time: e.time as DateTime,
    );
  }
}

// ---------- Tire snapshot (PSI only for now) ----------
class TireSnapshot {
  TireSnapshot({
    required this.name,
    required this.psi,
    required this.targetPsi,
  });

  final String name;
  final double psi;
  final double targetPsi;

  factory TireSnapshot.fromTire(Tire t) => TireSnapshot(
    name: t.name,
    psi: t.psi,
    targetPsi: t.targetPsi,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'psi': psi,
    'target_psi': targetPsi,
  };
}

// ---------- Session model (PSI only for now) ----------
class Session {
  Session({
    required this.timestamp,
    required this.tires,
    required this.inflateCount,
    required this.deflateCount,
    this.behaviorScore,
    required this.events,
  }) : avgPsi = _avg(tires.map((e) => e.psi));

  final DateTime timestamp;
  final List<TireSnapshot> tires;

  final int inflateCount;
  final int deflateCount;
  final double? behaviorScore;
  final List<EventSnapshot> events;

  final double avgPsi;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'avg_psi': avgPsi,
    'actions': {
      'inflates': inflateCount,
      'deflates': deflateCount,
    },
    'behavior_score': behaviorScore,
    'events': events.map((e) => e.toJson()).toList(),
    'tires': tires.map((t) => t.toJson()).toList(),
  };

  static double _avg(Iterable<double> xs) {
    final list = xs.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }
}

// ---------- Store ----------
class HistoryStore {
  static final List<Session> sessions = [];

  static int _inflates = 0;
  static int _deflates = 0;

  static double? _lastBehaviorScore;
  static List<EventSnapshot> _lastEvents = [];

  static void logInflate() => _inflates++;
  static void logDeflate() => _deflates++;

  static void setBehaviorSnapshot({
    required double score,
    required List<EventSnapshot> events,
  }) {
    _lastBehaviorScore = score;
    _lastEvents = List<EventSnapshot>.from(events);
  }

  static void setBehaviorSnapshotFromAny({
    required double score,
    required List<dynamic> events,
  }) {
    _lastBehaviorScore = score;
    _lastEvents = events.map((e) => EventSnapshot.fromAny(e)).toList();
  }

  static void addSessionFromTires(List<Tire> tires) {
    final snaps = tires.map(TireSnapshot.fromTire).toList();

    final s = Session(
      timestamp: DateTime.now(),
      tires: snaps,
      inflateCount: _inflates,
      deflateCount: _deflates,
      behaviorScore: _lastBehaviorScore,
      events: List<EventSnapshot>.from(_lastEvents),
    );
    sessions.insert(0, s);

    _inflates = 0;
    _deflates = 0;
  }

  static String toCsv() {
    final buf = StringBuffer('timestamp,tire,psi,target_psi\n');
    for (final s in sessions) {
      final ts = s.timestamp.toIso8601String();
      for (final t in s.tires) {
        buf.writeln(
          '$ts,${t.name},${_f(t.psi)},${_f(t.targetPsi)}',
        );
      }
    }
    return buf.toString();
  }

  static String toJsonString() {
    final jsonList = sessions.map((s) => s.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  static String _f(num x) => x.toStringAsFixed(2);

  static void seedSamplesIfEmpty() {
    if (sessions.isNotEmpty) return;
    final rng = Random(1);
    for (int i = 0; i < 6; i++) {
      final now = DateTime.now().subtract(Duration(hours: (i + 1) * 6));

      final tires = [
        TireSnapshot(name: 'Front Left',  psi: 28 + rng.nextDouble()*4, targetPsi: 32),
        TireSnapshot(name: 'Front Right', psi: 28 + rng.nextDouble()*4, targetPsi: 32),
        TireSnapshot(name: 'Rear Left',   psi: 27 + rng.nextDouble()*4, targetPsi: 32),
        TireSnapshot(name: 'Rear Right',  psi: 27 + rng.nextDouble()*4, targetPsi: 32),
      ];

      final inflates = rng.nextInt(3);
      final deflates = rng.nextInt(2);
      final score = 70 + rng.nextDouble() * 25;

      final evCount = 3 + rng.nextInt(5);
      final ev = List.generate(evCount, (idx) {
        final types = ['hardBrake', 'sharpTurn', 'overspeed'];
        final t = types[rng.nextInt(types.length)];
        final val = (t == 'hardBrake')
            ? (3.5 + rng.nextDouble()*2.5)
            : (t == 'sharpTurn'
            ? (0.35 + rng.nextDouble()*0.45)
            : (5 + rng.nextInt(31)).toDouble());
        final pen = 4 + rng.nextDouble()*10;
        final time = now.subtract(Duration(minutes: rng.nextInt(300)));
        return EventSnapshot(type: t, value: val, penalty: pen, time: time);
      });

      sessions.add(Session(
        timestamp: now,
        tires: tires,
        inflateCount: inflates,
        deflateCount: deflates,
        behaviorScore: score,
        events: ev,
      ));
    }
  }
}

// -------- Screen ----------
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    super.initState();
    HistoryStore.seedSamplesIfEmpty();
  }

  Future<void> _copyCsv() async {
    final csv = HistoryStore.toCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    _snack('CSV copied to clipboard (${csv.length} chars)');
  }

  Future<void> _copyJson() async {
    final js = HistoryStore.toJsonString();
    await Clipboard.setData(ClipboardData(text: js));
    _snack('JSON copied to clipboard (${js.length} chars)');
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final items = HistoryStore.sessions;

    return Scaffold(
      backgroundColor: kKFUPMGreen,
      appBar: AppBar(
        backgroundColor: kKFUPMGreen,
        foregroundColor: Colors.white,
        title: const Text('History & Reports', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Copy CSV',
            iconSize: 28,
            icon: const Icon(Icons.table_view),
            onPressed: _copyCsv,
          ),
          IconButton(
            tooltip: 'Copy JSON',
            iconSize: 28,
            icon: const Icon(Icons.data_object),
            onPressed: _copyJson,
          ),
        ],
      ),
      body: items.isEmpty ? _emptyState() : _list(items),
      floatingActionButton: items.isEmpty ? null : _exportFab(),
    );
  }

  Widget _list(List<Session> items) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(kPad),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final s = items[i];
          final ts = _fmt(s.timestamp);

          return Card(
            color: kKFUPMGold,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.white54,
                iconTheme: const IconThemeData(color: Colors.black87),
                textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: Colors.black,
                  displayColor: Colors.black,
                ),
              ),
              child: ExpansionTile(
                title: Text(ts, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Avg PSI ${s.avgPsi.toStringAsFixed(1)}'),
                children: [
                  const Divider(height: 1),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(kPad, kPad, kPad, 0),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.arrow_upward, size: 18, color: Colors.white),
                          label: Text('Inflates: ${s.inflateCount}',
                              style: const TextStyle(color: Colors.white)),
                          backgroundColor: kKFUPMGreen,
                        ),
                        Chip(
                          avatar: const Icon(Icons.arrow_downward, size: 18, color: Colors.white),
                          label: Text('Deflates: ${s.deflateCount}',
                              style: const TextStyle(color: Colors.white)),
                          backgroundColor: kKFUPMGreen,
                        ),
                        if (s.behaviorScore != null)
                          Chip(
                            avatar: const Icon(Icons.speed, size: 18, color: Colors.white),
                            label: Text('Safety score: ${s.behaviorScore!.toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.white)),
                            backgroundColor: Colors.orange.shade700,
                          ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(kPad),
                    child: Column(
                      children: s.tires.map((t) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.tire_repair, color: kKFUPMGreen),
                          title: Text(t.name),
                          subtitle: Text('PSI ${t.psi.toStringAsFixed(1)}'),
                          trailing: Text('Target ${t.targetPsi.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                    ),
                  ),

                  if (s.events.isNotEmpty) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, kPad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Driving events',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Container(
                            height: 220,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Scrollbar(
                              thumbVisibility: true,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: s.events.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final e = s.events[idx];
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: kKFUPMGreen.withOpacity(0.15),
                                      child: Icon(_iconFor(e.type),
                                          color: kKFUPMGreen, size: 18),
                                    ),
                                    title: Text(_titleFor(e)),
                                    subtitle: Text(_subtitleFor(e)),
                                    trailing: Text(
                                      '-${e.penalty.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  FloatingActionButton _exportFab() {
    return FloatingActionButton.extended(
      backgroundColor: kNavGrey,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.ios_share),
      label: const Text('Export'),
      onPressed: () async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: kKFUPMGold,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.table_view, color: kKFUPMGreen),
                  title: const Text('Copy CSV'),
                  onTap: () => Navigator.pop(context, 'csv'),
                ),
                ListTile(
                  leading: const Icon(Icons.data_object, color: kKFUPMGreen),
                  title: const Text('Copy JSON'),
                  onTap: () => Navigator.pop(context, 'json'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (choice == 'csv') _copyCsv();
        if (choice == 'json') _copyJson();
      },
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'hardBrake': return Icons.stop_circle_outlined;
      case 'sharpTurn': return Icons.turn_right;
      case 'overspeed': return Icons.speed;
      default: return Icons.info_outline;
    }
  }

  String _titleFor(EventSnapshot e) {
    switch (e.type) {
      case 'hardBrake': return 'Hard brake';
      case 'sharpTurn': return 'Sharp turn';
      case 'overspeed': return 'Overspeed';
      default: return e.type;
    }
  }

  String _subtitleFor(EventSnapshot e) {
    final ago = DateTime.now().difference(e.time);
    final when = ago.inSeconds < 60 ? '${ago.inSeconds}s ago' : '${ago.inMinutes}m ago';
    switch (e.type) {
      case 'hardBrake': return '${e.value.toStringAsFixed(1)} m/s² • $when';
      case 'sharpTurn': return '${e.value.toStringAsFixed(2)} g • $when';
      case 'overspeed': return '${e.value.toStringAsFixed(0)}% over • $when';
      default: return when;
    }
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kPad * 2),
        child: Card(
          color: kKFUPMGold,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(kPad * 1.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.folder_open, size: 72, color: kKFUPMGreen),
                const SizedBox(height: 12),
                const Text('No sessions yet',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                  'From Dashboard, tap the save icon to log a session.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kNavGrey,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate sample sessions'),
                  onPressed: () {
                    HistoryStore.seedSamplesIfEmpty();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
