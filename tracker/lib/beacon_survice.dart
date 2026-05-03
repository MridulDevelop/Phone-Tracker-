import 'package:flutter/material.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class BeaconService {

  // Short 16-bit UUID — takes minimum space in advertisement packet
  static const String APP_SERVICE_UUID = 'FFFE';
  static String? _deviceUUID;
  static final _peripheral = PeripheralManager();

  static Future<String> getDeviceUUID() async {
    if (_deviceUUID != null) return _deviceUUID!;
    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString('device_uuid');
    if (stored == null) {
      stored = _generateUUID();
      await prefs.setString('device_uuid', stored);
    }
    _deviceUUID = stored;
    return _deviceUUID!;
  }

  static String _generateUUID() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}'
        '${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}'
        '${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  static Future<bool> startAdvertising() async {
    // Step 1 — check permission
    final status = await Permission.bluetoothAdvertise.request();
    debugPrint("BEACON: Permission = $status");
    if (!status.isGranted) return false;

    try {
      // Step 2 — check bluetooth state properly
      // .state is a Stream so we listen to first value
      final currentState =  _peripheral.state;
      debugPrint("BEACON: BT State = $currentState");
      
      if (currentState != BluetoothLowEnergyState.poweredOn) {
        debugPrint("BEACON: Bluetooth not ready");
        return false;
      }

      // Step 3 — advertise with SHORT UUID only
      // No manufacturer data — keeps packet small to avoid error code 3
      final advertisement = Advertisement(
        serviceUUIDs: [UUID.fromString(APP_SERVICE_UUID)],
      );

      await _peripheral.startAdvertising(advertisement);
      debugPrint("BEACON: Broadcasting started successfully");
      return true;

    } catch (e) {
      debugPrint("BEACON: Failed = $e");
      return false;
    }
  }

  static Future<void> stopAdvertising() async {
    try {
      await _peripheral.stopAdvertising();
      debugPrint("BEACON: Stopped");
    } catch (e) {
      debugPrint("BEACON: Stop error = $e");
    }
  }
}