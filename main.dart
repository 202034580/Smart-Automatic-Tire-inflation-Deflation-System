import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'dashboard.dart';

// KFUPM brand colors
const Color kfupmGreen = Color(0xFF008540);
const Color kfupmGold  = Color(0xFFDAC961);

void main() => runApp(const TireSystemApp());

class TireSystemApp extends StatelessWidget {
  const TireSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Tire System',
      theme: ThemeData(useMaterial3: true),
      home: const IntroPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// --------------------------------------------------
/// 0) Intro / Team screen
/// --------------------------------------------------
class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  static const String title =
      'Smart automatic tire inflation and deflation';

  static const List<String> teamNames = [
    'Murtadha ALGhadban',
    'Hadi ALMayyad',
    'Hussain AL Haddad',
    'Fahad AL Faris',
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;

    final iconSize  = (w * 0.26).clamp(140, 200).toDouble();
    final titleSize = (w * 0.070).clamp(28, 40).toDouble();
    final subSize   = (w * 0.050).clamp(20, 28).toDouble();
    final nameSize  = (w * 0.045).clamp(18, 24).toDouble();
    final pad       = (w * 0.05).clamp(18, 32).toDouble();
    final btnH      = (w * 0.16).clamp(60, 72).toDouble();
    final btnText   = (w * 0.055).clamp(20, 24).toDouble();

    return Scaffold(
      backgroundColor: kfupmGreen,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: pad * 0.5),

                Icon(
                  Icons.directions_car_filled,
                  size: iconSize,
                  color: Colors.white,
                ),

                SizedBox(height: pad * 0.8),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),

                SizedBox(height: pad * 0.5),

                Text(
                  'Team number: 039',
                  style: TextStyle(
                    fontSize: subSize,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: pad),

                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(pad * 0.9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: pad,
                      runSpacing: pad * 0.6,
                      children: teamNames.map(
                            (n) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              n,
                              style: TextStyle(
                                fontSize: nameSize,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ).toList(),
                    ),
                  ),
                ),

                SizedBox(height: pad),

                SizedBox(
                  width: double.infinity,
                  height: btnH,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kfupmGold,
                      foregroundColor: Colors.white,
                      textStyle: TextStyle(
                        fontSize: btnText,
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 32),
                    label: const Text('Start'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ConnectionScreen(),
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(height: pad * 0.4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// --------------------------------------------------
/// BLE permissions helper
/// --------------------------------------------------
Future<bool> ensureBlePermissions() async {
  if (!Platform.isAndroid) return true;

  final statuses = await <Permission>[
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
  ].request();

  final scanStatus = statuses[Permission.bluetoothScan];
  final locStatus  = statuses[Permission.locationWhenInUse];

  final scanOk = scanStatus != null &&
      (scanStatus.isGranted || scanStatus.isLimited);

  if (!scanOk) {
    if (scanStatus?.isPermanentlyDenied == true) {
      await openAppSettings();
    }
    return false;
  }

  if (locStatus != null && locStatus.isPermanentlyDenied) {
    await openAppSettings();
  }

  return true;
}

/// --------------------------------------------------
/// 1) Bluetooth Connection Screen
/// --------------------------------------------------
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  bool _isScanning = false;
  StreamSubscription<bool>? _scanStateSub;

  @override
  void initState() {
    super.initState();
    _scanStateSub = FlutterBluePlus.isScanning.listen((s) {
      if (mounted) setState(() => _isScanning = s);
    });
  }

  @override
  void dispose() {
    _scanStateSub?.cancel();
    FlutterBluePlus.stopScan().catchError((_) {});
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    final ok = await ensureBlePermissions();
    if (!ok) {
      _showSnack('BLE permissions not granted.');
      return;
    }

    BluetoothAdapterState state;
    try {
      state = await FlutterBluePlus.adapterState.first;
    } catch (e) {
      _showSnack('Error: $e');
      return;
    }

    if (state != BluetoothAdapterState.on) {
      _showSnack('Bluetooth is OFF.');
      return;
    }

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 12),
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      _showSnack('Scan failed: $e');
    }
  }

  Future<void> _connectAndOpenDashboard(BluetoothDevice device) async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    final name = device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.str;

    _showSnack('Connecting to $name...');

    try {
      await device.connect(timeout: const Duration(seconds: 8));
    } catch (e) {
      _showSnack('Connection failed: $e');
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardPage(connectedDevice: device),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;

    final iconSize = (w * 0.28).clamp(140, 200).toDouble();
    final pad      = (w * 0.06).clamp(20, 32).toDouble();
    final btnH     = (w * 0.16).clamp(60, 72).toDouble();
    final btnText  = (w * 0.055).clamp(20, 24).toDouble();

    return Scaffold(
      backgroundColor: kfupmGreen,
      appBar: AppBar(
        backgroundColor: kfupmGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Bluetooth Connection',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Icon(Icons.bluetooth, size: iconSize, color: Colors.white),
              SizedBox(height: pad),

              SizedBox(
                width: double.infinity,
                height: btnH,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kfupmGold,
                    foregroundColor: Colors.white,
                    textStyle: TextStyle(
                      fontSize: btnText,
                      fontWeight: FontWeight.w900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  icon: Icon(
                    _isScanning
                        ? Icons.bluetooth_searching
                        : Icons.bluetooth,
                    size: 30,
                  ),
                  label: Text(_isScanning ? 'Scanning...' : 'Scan'),
                  onPressed: _isScanning ? null : _startScan,
                ),
              ),

              SizedBox(height: pad * 0.6),

              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: _buildDeviceList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return StreamBuilder<List<ScanResult>>(
      stream: FlutterBluePlus.scanResults,
      initialData: const [],
      builder: (context, snapshot) {
        final results = snapshot.data ?? const [];

        if (results.isEmpty && !_isScanning) {
          return const Center(
            child: Text(
              'No devices yet.\nTap "Scan" to search.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        if (results.isEmpty && _isScanning) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            color: Colors.white24,
          ),
          itemBuilder: (context, index) {
            final r   = results[index];
            final dev = r.device;
            final adv = r.advertisementData;

            final name = dev.platformName.isNotEmpty
                ? dev.platformName
                : (adv.advName.isNotEmpty ? adv.advName : '(no name)');

            final nmUpper = name.toUpperCase();
            final likelyHm10 = nmUpper.contains('HM') ||
                nmUpper.contains('BT05') ||
                adv.serviceUuids
                    .map((u) => u.toString().toLowerCase())
                    .any((u) => u.contains('ffe0'));

            return ListTile(
              onTap: () => _connectAndOpenDashboard(dev),
              title: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'RSSI ${r.rssi}'
                    '${likelyHm10 ? " • likely HM-10/BT-05" : ""}',
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: Colors.white70,
              ),
            );
          },
        );
      },
    );
  }
}
