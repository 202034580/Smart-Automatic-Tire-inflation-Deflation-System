// lib/compressor_test_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const Color kKFUPMGreen = Color(0xFF008540);
const Color kKFUPMGold  = Color(0xFFDAC961);
const Color kNavGrey    = Color(0xFF424242);

class CompressorTestPage extends StatefulWidget {
  const CompressorTestPage({super.key, required this.device});
  final BluetoothDevice device;

  @override
  State<CompressorTestPage> createState() => _CompressorTestPageState();
}

class _CompressorTestPageState extends State<CompressorTestPage> {
  BluetoothCharacteristic? _tx;
  BluetoothCharacteristic? _rx;
  bool _txWithoutResponse = false;

  bool _busy = true;
  int? _runningTire;

  final List<double> _psi = [0, 0, 0, 0];
  String _lastBle = "";
  String _rxBuffer = "";

  @override
  void initState() {
    super.initState();
    _setupBle();
  }

  Future<void> _setupBle() async {
    try {
      final d = widget.device;

      final state = await d.connectionState.first;
      if (state != BluetoothConnectionState.connected) {
        await d.connect(timeout: const Duration(seconds: 8));
      }

      // ✅ Better MTU (Android only, safe to call)
      try {
        await d.requestMtu(185);
      } catch (_) {}

      final services = await d.discoverServices();
      BluetoothCharacteristic? best;

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

      if (best == null) throw "FFE1 characteristic not found.";

      _tx = best;
      _rx = best;
      _txWithoutResponse = best.properties.writeWithoutResponse;

      if (_rx!.properties.notify) {
        await _rx!.setNotifyValue(true);
        _rx!.onValueReceived.listen(_onRx);
      }

      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _snack("BLE setup failed: $e");
    }
  }

  void _onRx(List<int> data) {
    // ✅ HM-10 sometimes gives malformed utf8
    final chunk = utf8.decode(data, allowMalformed: true);
    if (chunk.isEmpty) return;

    _rxBuffer += chunk;

    while (_rxBuffer.contains("\n")) {
      final idx = _rxBuffer.indexOf("\n");
      final line = _rxBuffer.substring(0, idx).trim();
      _rxBuffer = _rxBuffer.substring(idx + 1);

      if (line.isEmpty) continue;

      setState(() => _lastBle = line);

      if (line.startsWith("PSI:")) {
        final parts = line.split(":");
        if (parts.length >= 3) {
          final tire = int.tryParse(parts[1]) ?? 0;
          final val  = double.tryParse(parts[2]) ?? 0;
          if (tire >= 1 && tire <= 4) {
            setState(() => _psi[tire - 1] = val);
          }
        }
        continue;
      }

      if (line.startsWith("EVENT:")) {
        final parts = line.split(":");
        if (parts.length >= 3) {
          final type = parts[1];
          final tire = int.tryParse(parts[2]) ?? 0;

          if (type == "CAP_MAX") {
            _snack("Tire $tire reached 45 PSI cap. Stopped.");
            setState(() => _runningTire = null);
          } else if (type == "STOP") {
            setState(() => _runningTire = null);
          }
        }
        continue;
      }

      if (line.startsWith("ALERT:LEAK:")) {
        final parts = line.split(":");
        if (parts.length >= 4) {
          final tire = int.tryParse(parts[2]) ?? 0;
          final drop = double.tryParse(parts[3]) ?? 0;
          _showLeakDialog(tire, drop);
        }
        continue;
      }
    }
  }

  Future<void> _send(String cmd) async {
    if (_tx == null) return;
    setState(() => _busy = true);
    try {
      await _tx!.write(
        utf8.encode(cmd),
        withoutResponse: _txWithoutResponse,
      );
    } catch (e) {
      _snack("Send failed: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _anyRunning => _runningTire != null;

  Future<void> _inflate(int tire) async {
    if (_runningTire != null && _runningTire != tire) {
      _snack("Tire $_runningTire is running. Wait until it finishes.");
      return;
    }
    if (_psi[tire - 1] >= 45.0) {
      _snack("Tire $tire already at max cap (45 PSI).");
      return;
    }

    final ok = await _confirm(
      "Inflate Tire $tire?",
      "Will turn ON:\n"
          "- Tire $tire INF valve\n"
          "- Compressor (JD16)\n\n"
          "All other tires OFF.\n"
          "Stops automatically at 45 PSI.",
    );
    if (!ok) return;

    setState(() => _runningTire = tire);
    await _send("T$tire:I\n");
  }

  Future<void> _deflate(int tire) async {
    if (_runningTire != null && _runningTire != tire) {
      _snack("Tire $_runningTire is running. Wait until it finishes.");
      return;
    }

    final ok = await _confirm(
      "Deflate Tire $tire?",
      "Will turn ON:\n"
          "- Tire $tire DEF valve\n\n"
          "Compressor stays OFF.\n"
          "All other tires OFF.\n"
          "⚠️ No auto-stop at 10 PSI anymore.",
    );
    if (!ok) return;

    setState(() => _runningTire = tire);
    await _send("T$tire:D\n");
  }

  Future<void> _stop(int tire) async {
    await _send("T$tire:S\n");
    setState(() => _runningTire = null);
  }

  Future<bool> _confirm(String title, String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavGrey,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showLeakDialog(int tire, double drop) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Unusual Leak in Tire $tire"),
        content: Text(
          "Tire $tire lost ${drop.toStringAsFixed(2)} PSI in 15 seconds while idle.\n"
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kKFUPMGreen,
      appBar: AppBar(
        backgroundColor: kKFUPMGreen,
        foregroundColor: Colors.white,
        title: const Text(
          "Compressor / Valves Test",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 4,
        itemBuilder: (context, i) {
          final tire = i + 1;
          final running = _runningTire == tire;
          final locked = _anyRunning && !running;

          return Card(
            color: kKFUPMGold,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tire $tire",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Live PSI: ${_psi[i].toStringAsFixed(1)}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kNavGrey,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: locked ? null : () => _inflate(tire),
                          icon: const Icon(Icons.arrow_upward,
                              color: Colors.green),
                          label: const Text("Inflate"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kNavGrey,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: locked ? null : () => _deflate(tire),
                          icon: const Icon(Icons.arrow_downward,
                              color: Colors.red),
                          label: const Text("Deflate"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 95,
                        height: 65,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: running
                                ? Colors.red.shade800
                                : Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed:
                          running ? () => _stop(tire) : null,
                          child: const Icon(Icons.stop_circle, size: 40),
                        ),
                      ),
                    ],
                  ),
                  if (running)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "Running now… other tires locked",
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
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
