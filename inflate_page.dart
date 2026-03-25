// ===============================
// inflate_page.dart (FULL UPDATED)
// Adds STOP button -> sends "Tn:S\n"
// ===============================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'tire_model.dart';
import 'settings.dart';
import 'history.dart';

// ===== Brand colors =====
const Color kKFUPMGreen = Color(0xFF008540);
const Color kKFUPMGold  = Color(0xFFDAC961);
const Color kNavGrey    = Color(0xFF424242);

class InflatePage extends StatefulWidget {
  const InflatePage({
    super.key,
    required this.tire,
    this.device,
  });

  final Tire tire;

  /// Connected BLE device (HM-10)
  final BluetoothDevice? device;

  @override
  State<InflatePage> createState() => _InflatePageState();
}

class _InflatePageState extends State<InflatePage> {
  static const double kPad = 12;
  static const double kMinPsi = 10.0;
  static const double kMaxPsi = 45.0;

  late double _min;
  late double _max;
  late double _target;
  late final TextEditingController _ctrl;

  BluetoothCharacteristic? _tx;
  bool _txWithoutResponse = false;
  bool _busyBle = false;

  @override
  void initState() {
    super.initState();
    final psi = widget.tire.psi;

    _min = psi.ceilToDouble().clamp(kMinPsi, kMaxPsi);
    _max = kMaxPsi;
    _target = (widget.tire.targetPsi > psi ? widget.tire.targetPsi : _min)
        .clamp(_min, _max);
    _ctrl = TextEditingController(text: _target.toStringAsFixed(0));

    if (widget.device != null) {
      _setupBle(widget.device!);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Map tire name to Arduino tire number (1..4)
  int _tireNumFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('front left')) return 1;
    if (n.contains('front right')) return 2;
    if (n.contains('rear left')) return 3;
    if (n.contains('rear right')) return 4;
    return 1; // safe default
  }

  Future<void> _setupBle(BluetoothDevice d) async {
    setState(() => _busyBle = true);
    try {
      final state = await d.connectionState.first;
      if (state != BluetoothConnectionState.connected) {
        await d.connect(timeout: const Duration(seconds: 8));
      }

      // Better MTU on Android (safe to call)
      try { await d.requestMtu(185); } catch (_) {}

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
      _txWithoutResponse = best.properties.writeWithoutResponse;

      if (mounted) setState(() => _busyBle = false);
    } catch (e) {
      if (mounted) setState(() => _busyBle = false);
      debugPrint("InflatePage BLE setup failed: $e");
    }
  }

  void _syncFromField(String txt) {
    final v = double.tryParse(txt);
    if (v == null) return;
    setState(() => _target = v);
  }

  void _commitTarget() {
    final clamped = _target.clamp(_min, _max).toDouble();
    setState(() {
      _target = clamped;
      _ctrl.text = clamped.toStringAsFixed(0);
      _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length),
      );
    });
  }

  Future<bool> _confirmApply() async {
    final t = widget.tire;
    final targetPsi = _target.toStringAsFixed(0);
    final targetDisplay = AppSettings.fmtPsi1(_target);
    final currentDisplay = AppSettings.fmtPsi1(t.psi);

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm inflate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tire: ${t.name}'),
            const SizedBox(height: 6),
            Text('Current: $currentDisplay'),
            Text('Target: $targetPsi PSI  ($targetDisplay)'),
            const SizedBox(height: 8),
            Text(
              'Proceed to start inflating? (Auto-stops at 45 PSI)',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavGrey,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _sendBleInflateCommand() async {
    final device = widget.device;
    if (device == null) {
      debugPrint('InflatePage: device is null');
      return;
    }

    // Ensure TX exists (in case setup failed or page opened without BLE ready)
    if (_tx == null) {
      await _setupBle(device);
    }
    if (_tx == null) {
      debugPrint('InflatePage: no TX characteristic found');
      return;
    }

    final tireNum = _tireNumFromName(widget.tire.name);
    final cmd = 'T$tireNum:I\n'; // ✅ matches Arduino handleCommand()

    setState(() => _busyBle = true);
    try {
      await _tx!.write(
        utf8.encode(cmd),
        withoutResponse: _txWithoutResponse,
      );
      debugPrint('InflatePage: sent "$cmd"');
    } catch (e) {
      debugPrint('InflatePage BLE send error: $e');
    } finally {
      if (mounted) setState(() => _busyBle = false);
    }
  }

  // ✅ STOP: sends "Tn:S\n"
  Future<void> _sendBleStopCommand() async {
    final device = widget.device;
    if (device == null) {
      debugPrint('InflatePage Stop: device is null');
      return;
    }

    if (_tx == null) {
      await _setupBle(device);
    }
    if (_tx == null) {
      debugPrint('InflatePage Stop: no TX characteristic found');
      return;
    }

    final tireNum = _tireNumFromName(widget.tire.name);
    final cmd = 'T$tireNum:S\n'; // ✅ matches Arduino handleCommand()

    setState(() => _busyBle = true);
    try {
      await _tx!.write(
        utf8.encode(cmd),
        withoutResponse: _txWithoutResponse,
      );
      debugPrint('InflatePage: sent "$cmd"');
    } catch (e) {
      debugPrint('InflatePage Stop BLE send error: $e');
    } finally {
      if (mounted) setState(() => _busyBle = false);
    }
  }

  Future<void> _apply() async {
    _commitTarget();

    // optional guard: if already at cap, don’t inflate
    if (widget.tire.psi >= kMaxPsi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already at 45 PSI cap.')),
      );
      return;
    }

    final ok = await _confirmApply();
    if (!ok) return;

    setState(() => widget.tire.targetPsi = _target);

    await _sendBleInflateCommand();

    HistoryStore.logInflate();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Inflate ${widget.tire.name} confirmed (auto stop at 45 PSI)',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tire;
    final outOfRange = _target < _min || _target > _max;

    return Scaffold(
      backgroundColor: kKFUPMGreen,
      appBar: AppBar(
        backgroundColor: kKFUPMGreen,
        foregroundColor: Colors.white,
        title: const Text('Inflate', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              backgroundColor: Colors.white24,
              label: Text(
                t.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(kPad),
        children: [
          Card(
            color: kKFUPMGold,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.tire_repair, color: kKFUPMGreen),
              title: Text(
                t.name,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
              ),
              subtitle: const Text('Selected tire', style: TextStyle(color: Colors.black87)),
            ),
          ),

          // ✅ Only show PSI (temp/tread removed)
          Card(
            color: kKFUPMGold,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(kPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppSettings.fmtPsi1(t.psi),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Current pressure",
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ),

          Card(
            color: kKFUPMGold,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(kPad),
              child: Column(
                children: [
                  const Text('Set target (PSI)', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: '−1 PSI',
                        icon: const Icon(Icons.remove, color: kKFUPMGreen),
                        onPressed: () {
                          setState(() {
                            _target = (_target - 1).clamp(_min, _max);
                            _ctrl.text = _target.toStringAsFixed(0);
                          });
                        },
                      ),

                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _ctrl,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Target PSI',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: _syncFromField,
                          onSubmitted: (_) => _commitTarget(),
                        ),
                      ),

                      IconButton(
                        tooltip: '+1 PSI',
                        icon: const Icon(Icons.add, color: kKFUPMGreen),
                        onPressed: () {
                          setState(() {
                            _target = (_target + 1).clamp(_min, _max);
                            _ctrl.text = _target.toStringAsFixed(0);
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Range: ≥ current • ${_min.toStringAsFixed(0)}–${_max.toStringAsFixed(0)} PSI',
                    style: TextStyle(color: outOfRange ? Colors.red : Colors.black54),
                  ),
                  const SizedBox(height: 12),

                  // ✅ Apply + STOP + Cancel
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kNavGrey,
                            foregroundColor: Colors.white,
                          ),
                          icon: _busyBle
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.check),
                          label: const Text('Apply & Inflate'),
                          onPressed: (outOfRange || _busyBle) ? null : _apply,
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.stop_circle),
                          label: const Text('STOP'),
                          onPressed: _busyBle
                              ? null
                              : () async {
                            await _sendBleStopCommand();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Stop command sent')),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kNavGrey,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                          onPressed: _busyBle ? null : () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
