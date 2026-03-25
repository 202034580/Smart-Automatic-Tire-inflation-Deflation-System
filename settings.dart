import 'package:flutter/material.dart';

/// -----------------------------------------
/// App-wide settings / unit helpers (unchanged)
/// -----------------------------------------
enum PressureUnits { psi, bar }

class AppSettings {
  static bool autoReconnect = true;
  static PressureUnits units = PressureUnits.psi;

  // Matching your real hardware range (Arduino caps at 45 PSI)
  static double lowPsi = 10.0;
  static double highPsi = 45.0;

  static const double _psiToBar = 0.0689476;

  static String unitLabel() => units == PressureUnits.psi ? 'PSI' : 'bar';

  static double psiToDisplay(double psi) =>
      units == PressureUnits.psi ? psi : psi * _psiToBar;

  static String fmtPsi1(double psi) {
    final v = psiToDisplay(psi);
    final suffix = unitLabel();
    final decimals = units == PressureUnits.psi ? 1 : 2;
    return '${v.toStringAsFixed(decimals)} $suffix';
  }

  static String fmtTarget(double psi) {
    final v = psiToDisplay(psi);
    final decimals = units == PressureUnits.psi ? 0 : 2;
    return 'Target: ${v.toStringAsFixed(decimals)}';
  }
}

/// -----------------------------------------
/// KFUPM brand colors & helpers
/// -----------------------------------------
const Color kKFUPMGreen = Color(0xFF008540); // background, icons, actives
const Color kKFUPMGold  = Color(0xFFDAC961); // cards
const Color kNavGrey    = Color(0xFF424242); // buttons (white text)
const double kPad = 12.0;

ButtonStyle greyButton() => ElevatedButton.styleFrom(
  backgroundColor: kNavGrey,
  foregroundColor: Colors.white,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
);

Widget sectionCard(Widget child) => Card(
  color: kKFUPMGold,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  child: Padding(padding: const EdgeInsets.all(kPad), child: child),
);

/// -----------------------------------------
/// Settings screen (brand-styled)
/// -----------------------------------------
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _auto;
  late PressureUnits _units;
  late TextEditingController _low;
  late TextEditingController _high;

  @override
  void initState() {
    super.initState();
    _auto = AppSettings.autoReconnect;
    _units = AppSettings.units;

    // Updated defaults here too
    _low = TextEditingController(text: AppSettings.lowPsi.toStringAsFixed(0));
    _high = TextEditingController(text: AppSettings.highPsi.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _low.dispose();
    _high.dispose();
    super.dispose();
  }

  void _saveAndPop() {
    AppSettings.autoReconnect = _auto;
    AppSettings.units = _units;

    final low = double.tryParse(_low.text);
    final high = double.tryParse(_high.text);
    if (low != null) AppSettings.lowPsi = low;
    if (high != null) AppSettings.highPsi = high;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _auto = true;
      _units = PressureUnits.psi;

      // Recommended resets
      _low.text = '10';
      _high.text = '45';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kKFUPMGreen,
      appBar: AppBar(
        backgroundColor: kKFUPMGreen,
        foregroundColor: Colors.white,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              style: greyButton(),
              onPressed: _saveAndPop,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(kPad),
        children: [
          // ---- BLE Auto-reconnect ----
          sectionCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bluetooth',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                SwitchListTile(
                  activeColor: kKFUPMGreen,
                  title: const Text('BLE auto-reconnect',
                      style: TextStyle(color: Colors.black)),
                  subtitle: const Text('Try to reconnect to the last device automatically',
                      style: TextStyle(color: Colors.black87)),
                  value: _auto,
                  onChanged: (v) => setState(() => _auto = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // ---- Units ----
          sectionCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pressure units',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text('Affects how PSI is displayed in the UI',
                    style: TextStyle(color: Colors.black87)),
                RadioListTile<PressureUnits>(
                  activeColor: kKFUPMGreen,
                  title: const Text('PSI', style: TextStyle(color: Colors.black)),
                  value: PressureUnits.psi,
                  groupValue: _units,
                  onChanged: (v) => setState(() => _units = v!),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<PressureUnits>(
                  activeColor: kKFUPMGreen,
                  title: const Text('bar', style: TextStyle(color: Colors.black)),
                  value: PressureUnits.bar,
                  groupValue: _units,
                  onChanged: (v) => setState(() => _units = v!),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // ---- Thresholds ----
          sectionCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alert thresholds',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 6),
                const Text('For future use in warnings',
                    style: TextStyle(color: Colors.black87)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _low,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Low PSI',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _high,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'High PSI',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ---- About ----
          sectionCard(
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline, color: kKFUPMGreen),
              title: const Text('About',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
              subtitle: const Text(
                'Tire System demo • Live BLE mode • v0.1.0',
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ),

          // ---- Reset ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton.icon(
              style: greyButton(),
              onPressed: _reset,
              icon: const Icon(Icons.restore),
              label: const Text('Reset to defaults'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
