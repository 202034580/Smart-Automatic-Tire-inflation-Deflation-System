import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'history.dart'; // for HistoryStore.setBehaviorSnapshotFromAny

/// ===== Brand colors =====
const Color kKFUPMGreen = Color(0xFF008540); // background, icons, accents
const Color kKFUPMGold  = Color(0xFFDAC961); // cards
const Color kNavGrey    = Color(0xFF424242); // buttons if needed
const double kPad = 12.0;

void snack(BuildContext c, String msg) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));

/// ----- Event model (screen-local) -----
enum EventType { hardBrake, sharpTurn, overspeed }

class DrivingEvent {
  DrivingEvent({
    required this.type,
    required this.value,
    required this.penalty,
    required this.time,
  });
  final EventType type;
  final double value;   // m/s², g, or % overspeed
  final double penalty; // score points to subtract (capped later at 15)
  final DateTime time;
}

/// ----- Behavior screen (event every 8s, score recovers between events) -----
class BehaviorPage extends StatefulWidget {
  const BehaviorPage({super.key});
  @override
  State<BehaviorPage> createState() => _BehaviorPageState();
}

class _BehaviorPageState extends State<BehaviorPage> {
  final _rng = Random();
  Timer? _tick;

  double _score = 92; // start slightly below 100
  final List<DrivingEvent> _events = [];
  final List<double> _history = [];
  static const int historyMax = 120;

  int _secToEvent = 8; // countdown to next event

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _onTick() {
    // Decrement first; when it hits 0, fire an event, then reset to 8.
    _secToEvent--;

    if (_secToEvent <= 0) {
      // Trigger exactly one event every 8s
      final now = DateTime.now();
      final e = _makeRandomEvent(now);
      final penalty = e.penalty.clamp(0, 15).toDouble();
      _events.insert(0, e);
      if (_events.length > 300) _events.removeLast();
      _score = (_score - penalty).clamp(0, 100);
      _secToEvent = 8; // reset countdown
    } else {
      // Normal driving between events: recover slowly, tapering near 90
      final rec = _recoveryPerSecond(_score);
      _score = (_score + rec).clamp(0, 100);
    }

    _history.add(_score);
    if (_history.length > historyMax) _history.removeAt(0);

    // Push snapshot so "Save Session" captures score + events
    HistoryStore.setBehaviorSnapshotFromAny(
      score: _score,
      events: _events,
    );

    if (mounted) setState(() {});
  }

  // Reduced recovery so >90 is hard:
  // Base 0.45 pts/s up to 85. From 85→100 it linearly tapers toward 0.
  double _recoveryPerSecond(double score) {
    const base = 0.45;
    if (score <= 85) return base;
    final taper = (100 - score) / (100 - 85); // 1.0 at 85, ~0 near 100
    return base * taper.clamp(0.0, 1.0);
  }

  DrivingEvent _makeRandomEvent(DateTime now) {
    final t = EventType.values[_rng.nextInt(3)];
    switch (t) {
      case EventType.hardBrake: {
        final decel = 3.5 + _rng.nextDouble() * 2.5; // 3.5–6.0 m/s²
        final penalty = _map(decel, 3.5, 6.0, 6, 14);
        return DrivingEvent(type: t, value: decel, penalty: penalty, time: now);
      }
      case EventType.sharpTurn: {
        final g = 0.35 + _rng.nextDouble() * 0.45;    // 0.35–0.8 g
        final penalty = _map(g, 0.35, 0.8, 5, 12);
        return DrivingEvent(type: t, value: g, penalty: penalty, time: now);
      }
      case EventType.overspeed: {
        final pct = 5 + _rng.nextInt(31);             // 5–35 %
        final penalty = _map(pct.toDouble(), 5, 35, 6, 15);
        return DrivingEvent(type: t, value: pct.toDouble(), penalty: penalty, time: now);
      }
    }
  }

  double _map(double x, double inMin, double inMax, double outMin, double outMax) {
    final r = (x - inMin) / (inMax - inMin);
    return outMin + r * (outMax - outMin);
  }

  String get _label {
    if (_score >= 85) return 'Safe';
    if (_score >= 70) return 'Moderate';
    return 'Risky';
  }

  Color get _labelColor {
    if (_score >= 85) return kKFUPMGreen;
    if (_score >= 70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kKFUPMGreen,
      appBar: AppBar(
        backgroundColor: kKFUPMGreen,
        foregroundColor: Colors.white,
        title: const Text('Driving Behavior', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => snack(context, 'Simulated IMU/GPS analytics (no sensors yet).'),
          ),
        ],
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          padding: const EdgeInsets.all(kPad),
          children: [
            // Score header (GOLD card)
            Card(
              color: kKFUPMGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(kPad),
                child: Row(
                  children: [
                    // Big score & progress
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _score.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Safety Score (0–100) • Normal driving… (~$_secToEvent s to next event)',
                            style: const TextStyle(color: Colors.black87),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _score / 100,
                              minHeight: 10,
                              color: _labelColor, // green/orange/red
                              backgroundColor: Colors.white.withOpacity(0.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Label chip + tiny trend
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Chip(
                          label: Text(_label, style: const TextStyle(color: Colors.white)),
                          backgroundColor: _labelColor,
                        ),
                        const SizedBox(height: 8),
                        const Text('Trend', style: TextStyle(color: Colors.black87)),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 140,
                          height: 60,
                          child: _ScoreSparkline(data: _history),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Recent events (scrollable)
            Card(
              color: kKFUPMGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(kPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recent Events', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                    const SizedBox(height: 8),
                    if (_events.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No events yet', style: TextStyle(color: Colors.black54)),
                      )
                    else
                      SizedBox(
                        height: 300,
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.separated(
                            itemCount: _events.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final e = _events[i];
                              final pen = e.penalty.clamp(0, 15).toDouble();
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: kKFUPMGreen.withOpacity(0.15),
                                  child: Icon(_eventIcon(e.type), color: kKFUPMGreen, size: 18),
                                ),
                                title: Text(_eventTitle(e), style: const TextStyle(color: Colors.black)),
                                subtitle: Text(_eventSubtitle(e), style: const TextStyle(color: Colors.black87)),
                                trailing: Text(
                                  '-${pen.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // UI helpers
  IconData _eventIcon(EventType t) {
    switch (t) {
      case EventType.hardBrake: return Icons.stop_circle_outlined;
      case EventType.sharpTurn: return Icons.turn_right;
      case EventType.overspeed: return Icons.speed;
    }
  }

  String _eventTitle(DrivingEvent e) {
    switch (e.type) {
      case EventType.hardBrake: return 'Hard brake';
      case EventType.sharpTurn: return 'Sharp turn';
      case EventType.overspeed: return 'Overspeed';
    }
  }

  String _eventSubtitle(DrivingEvent e) {
    final ago = DateTime.now().difference(e.time);
    final when = ago.inSeconds < 60 ? '${ago.inSeconds}s ago' : '${ago.inMinutes}m ago';
    switch (e.type) {
      case EventType.hardBrake: return '${e.value.toStringAsFixed(1)} m/s² • $when';
      case EventType.sharpTurn: return '${e.value.toStringAsFixed(2)} g • $when';
      case EventType.overspeed: return '${e.value.toStringAsFixed(0)}% over • $when';
    }
  }
}

/// ----- tiny sparkline painter (no packages) -----
class _ScoreSparkline extends StatelessWidget {
  const _ScoreSparkline({required this.data});
  final List<double> data;
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparkPainter(data),
      child: const SizedBox.expand(),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.data);
  final List<double> data;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white.withOpacity(0.35);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)),
      bg,
    );
    if (data.length < 2) return;

    final minVal = data.reduce(min).toDouble();
    final maxVal = data.reduce(max).toDouble();
    final span = (maxVal - minVal).abs() < 1 ? 1 : (maxVal - minVal);

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = size.width * (i / (data.length - 1));
      final y = size.height * (1 - ((data[i] - minVal) / span));
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kKFUPMGreen;
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) => oldDelegate.data != data;
}
