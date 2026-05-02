import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:typed_data';
class BeaconService {
  // Same two UUID concept as before — nothing changes here
  static const String APP_SERVICE_UUID = '550e8400-e29b-41d4-a716-446655440000';
  static String? _deviceUUID;

  static final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  // ── Get or generate this device's permanent UUID ──
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
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
           '${hex(bytes[4])}${hex(bytes[5])}-'
           '${hex(bytes[6])}${hex(bytes[7])}-'
           '${hex(bytes[8])}${hex(bytes[9])}-'
           '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}'
           '${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  // ── Check if advertising is supported on this device ──
  static Future<bool> isSupported() async {
    return await _peripheral.isSupported;
  }

  // ── Start broadcasting as a beacon ──
  static Future<bool> startAdvertising() async {
    // Check permission first
    final status = await Permission.bluetoothAdvertise.request();
    debugPrint("Advertise permission: $status");// check this first
    if (!status.isGranted) return false;

    // Check hardware support
    final supported = await _peripheral.isSupported;
    debugPrint("BLE peripheral supported: $supported");
    if (!supported) return false;

    final deviceUUID = await getDeviceUUID();
    debugPrint("Device UUID: $deviceUUID");

    // AdvertiseData is what gets broadcast over the air
    final advertiseData = AdvertiseData(
      serviceUuid: APP_SERVICE_UUID,   // app identifier all installs share
      localName: 'OfflineTracker',
      manufacturerData: Uint8List.fromList(_uuidToBytes(deviceUUID).sublist(0,8)), 
      manufacturerId: 0x1234,
    );

    try {
      await _peripheral.start(advertiseData: advertiseData);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Stop broadcasting ──
  static Future<void> stopAdvertising() async {
    await _peripheral.stop();
  }

  // ── Stream to monitor advertising state changes ──
  static Stream<PeripheralState> get stateStream =>
      _peripheral.onPeripheralStateChanged!;

  // Convert UUID string → bytes for manufacturer data
  static List<int> _uuidToBytes(String uuid) {
    final hex = uuid.replaceAll('-', '');
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}