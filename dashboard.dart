import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'tire_model.dart';
import 'tire_card.dart';
import 'inflate_page.dart';
import 'deflate_page.dart';
import 'compressor_test_page.dart';

import 'settings.dart';
import 'history.dart';

// ===== Brand colors =====
const Color kKFUPMGreen = Color(0xFF008540);
const Color kKFUPMGold  = Color(0xFFDAC961);
const Color kNavGrey    = Color(0xFF424242);

const double kPad = 12.0;
const double kDesiredTileHeight = 250.0;

// ✅ Tire name mapping (for leak popups)
const List<String> tireNames = [
  "Front Left",   // Tire 1
  "Front Right",  // Tire 2
  "Rear Left",    // Tire 3
  "Rear Right",   // Tire 4
];

String tireName(int n) {
  if (n >= 1 && n <= 4) return tireNames[n - 1];
  return "Tire $n";
}

void snack(BuildContext c, String msg) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.connectedDevice});
  final BluetoothDevice? connectedDevice;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Start with PSI = 0.0 until BLE gives real values
  final List<Tire> _tires = [
    Tire(name: 'Front Left',  psi: 0.0, targetPsi: 0.0),
    Tire(name: 'Front Right', psi: 0.0, targetPsi: 0.0),
    Tire(name: 'Rear Left',   psi: 0.0, targetPsi: 0.0),
    Tire(name: 'Rear Right',  psi: 0.0, targetPsi: 0.0),
  ];

  BluetoothCharacteristic? _rx;
  StreamSubscription<List<int>>? _rxSub;

  bool _busy = false;
  String _lastBle = "";
  String _rxBuffer = "";

  // If BLE stops sending -> reset PSI to 0.0
  Timer? _noDataTimer;
  static const Duration kNoDataTimeout = Duration(seconds: 3);

  // Leak popup anti-spam (per tire)
  final Map<int, DateTime> _lastLeakShown = {};
  static const Duration kLeakCooldown = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();

    if (widget.connectedDevice != null) {
      _setupBle(widget.connectedDevice!);
    } else {
      // Explicit default when no BLE device
      for (final t in _tires) {
        t.psi = 0.0;
        t.actuator = Actuator.idle;
      }
      _lastBle = "No Bluetooth device → PSI: 0.0";
    }
  }

  @override
  void dispose() {
    _rxSub?.cancel();
    _noDataTimer?.cancel();
    super.dispose();
  }

  void _resetNoDataTimer() {
    _noDataTimer?.cancel();
    _noDataTimer = Timer(kNoDataTimeout, () {
      if (!mounted) return;
      setState(() {
        for (final t in _tires) t.psi = 0.0;
        _lastBle = "No BLE data → PSI reset to 0.0";
      });
    });
  }

  Future<void> _setupBle(BluetoothDevice d) async {
    setState(() => _busy = true);
    try {
      final state = await d.connectionState.first;
      if (state != BluetoothConnectionState.connected) {
        await d.connect(timeout: const Duration(seconds: 8));
      }

      // MTU boost on Android (safe to try)
      try { await d.requestMtu(185); } catch (_) {}

      final services = await d.discoverServices();
      BluetoothCharacteristic? best;

      // HM-10 usually exposes FFE1
      for (final s in services) {
        for (final c in s.characteristics) {
          final uuid = c.uuid.toString().toLowerCase();
          if (uuid.contains("ffe1")) {
            best = c;
            break;
          }
        }
        if (best != null) break;
      }

      if (best == null) throw "FFE1 characteristic not found";

      _rx = best;

      if (_rx!.properties.notify) {
        await _rx!.setNotifyValue(true);
        _rxSub = _rx!.onValueReceived.listen(_onRx);
      }

      if (mounted) setState(() => _busy = false);
      snack(context, "BLE connected. Live PSI enabled.");
      _resetNoDataTimer();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      snack(context, "BLE setup failed: $e");
    }
  }

  // Leak alert popup (now shows names)
  void _showLeakDialog(int tire, double drop) {
    if (!mounted) return;

    final now = DateTime.now();
    final last = _lastLeakShown[tire];
    if (last != null && now.difference(last) < kLeakCooldown) {
      return; // ignore repeat alerts too close together
    }
    _lastLeakShown[tire] = now;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Unusual Leak in ${tireName(tire)}"),
        content: Text(
          "${tireName(tire)} lost ${drop.toStringAsFixed(2)} PSI in 15 seconds while idle.\n"
              "Check for puncture or loose valve.",
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavGrey,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _onRx(List<int> data) {
    final chunk = utf8.decode(data, allowMalformed: true);
    if (chunk.trim().isEmpty) return;

    _resetNoDataTimer();
    _rxBuffer += chunk;

    while (_rxBuffer.contains("\n")) {
      final idx = _rxBuffer.indexOf("\n");
      final line = _rxBuffer.substring(0, idx).trim();
      _rxBuffer = _rxBuffer.substring(idx + 1);

      if (line.isEmpty) continue;

      setState(() => _lastBle = line);

      // ✅ Expected from Arduino:
      // PSI:1:28.5
      if (line.startsWith("PSI:")) {
        final parts = line.split(":");
        if (parts.length >= 3) {
          final tireNum = int.tryParse(parts[1]) ?? 0;
          final val = double.tryParse(parts[2]) ?? 0.0;

          if (tireNum >= 1 && tireNum <= 4) {
            setState(() {
              _tires[tireNum - 1].psi = val;
            });
          }
        }
        continue;
      }

      // ✅ Leak alert from Arduino:
      // ALERT:LEAK:3:1.25
      if (line.startsWith("ALERT:LEAK:")) {
        final parts = line.split(":");
        if (parts.length >= 4) {
          final tire = int.tryParse(parts[2]) ?? 0;
          final drop = double.tryParse(parts[3]) ?? 0.0;
          if (tire >= 1 && tire <= 4 && drop > 0) {
            _showLeakDialog(tire, drop);
          }
        }
        continue;
      }

      // (Optional future)
      // if (line.startsWith("STATE:")) { ... update _tires[n-1].actuator ... }
    }
  }

  Future<void> _disconnect() async {
    try { await widget.connectedDevice?.disconnect(); } catch (_) {}
    if (!mounted) return;

    setState(() {
      for (final t in _tires) t.psi = 0.0;
      _lastBle = "Disconnected → PSI reset to 0.0";
    });

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.connectedDevice != null;

    return Scaffold(
      backgroundColor: kKFUPMGreen,
      appBar: AppBar(
        backgroundColor: kKFUPMGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Disconnect Bluetooth',
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: _disconnect,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'settings') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()));
              } else if (v == 'save') {
                HistoryStore.addSessionFromTires(_tires);
                snack(context, 'Session saved');
              } else if (v == 'history') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HistoryPage()));
              } else if (v == 'compressor') {
                if (!connected) {
                  snack(context, "Connect Bluetooth first");
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CompressorTestPage(
                      device: widget.connectedDevice!,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'save', child: Text('Save Session')),
              PopupMenuItem(value: 'history', child: Text('History & Reports')),
              PopupMenuItem(value: 'compressor', child: Text('Compressor Test')),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(kPad),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                connected ? "Live Mode (BLE)" : "No device → PSI: 0.0",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          Expanded(
            child: _busy
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 700 ? 3 : 2;
                final gaps = 12.0 * (cols - 1) + 24.0;
                final itemWidth = (c.maxWidth - gaps) / cols;
                final ratio = itemWidth / kDesiredTileHeight;

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: ratio,
                  ),
                  itemCount: _tires.length,
                  itemBuilder: (context, i) {
                    final t = _tires[i];

                    return TireCard(
                      tire: t,
                      onDeflate: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeflatePage(
                            tire: t,
                            device: widget.connectedDevice,
                          ),
                        ),
                      ),
                      onInflate: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InflatePage(
                            tire: t,
                            device: widget.connectedDevice,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        color: kKFUPMGreen,
        padding: const EdgeInsets.all(10),
        child: Text(
          "Last BLE: $_lastBle",
          style: const TextStyle(color: Colors.white70),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
