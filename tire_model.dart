import 'package:flutter/material.dart';

/// Tire actuator state (shown on Dashboard)
enum Actuator { idle, inflating, deflating }

class Tire {
  String name;

  /// Live PSI value coming from Arduino BLE (PSI:1:xx.x)
  double psi;

  /// Target PSI chosen in Inflate/Deflate screens
  double targetPsi;

  /// Reserved for future (temp & tread sensors)
  double temp;
  double treadMm;

  /// Valve/compressor state (Idle / Inflating / Deflating)
  Actuator actuator;

  Tire({
    required this.name,
    required this.psi,
    required this.targetPsi,
    this.temp = 0.0,
    this.treadMm = 0.0,
    this.actuator = Actuator.idle,
  });

  // UI color for the state dot
  Color get statusColor {
    switch (actuator) {
      case Actuator.inflating:
        return Colors.orange;
      case Actuator.deflating:
        return Colors.blue;
      case Actuator.idle:
      default:
        return Colors.green;
    }
  }

  // Text shown under PSI
  String get actuatorLabel {
    switch (actuator) {
      case Actuator.inflating:
        return "Inflating";
      case Actuator.deflating:
        return "Deflating";
      case Actuator.idle:
      default:
        return "Idle";
    }
  }
}
