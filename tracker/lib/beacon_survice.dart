import 'package:flutter/material.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class BeaconService {

  // Short 16-bit UUID — takes minimum space in advertisement packet
  static const String APP_SERVICE_UUID = 'FFFE';
  static String? _deviceUUID;
  static String? _displayName;
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

static Future<void> initialize() async {
  try{
     // This triggers PeripheralManager to request its permissions
    // and transition from unauthorized → poweredOn
    final state = _peripheral.state;
    debugPrint("BEACON: Initial Bluetooth state = $state");
    _peripheral.stateChanged.listen((newState) {
      debugPrint("BEACON: Bluetooth state changed = $newState");
    });
  } catch (e) {
    debugPrint("BEACON: Initialization error = $e");
  }
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

static Future<String> _buildBroadcastName() async {
  final displayName = await getDisplayName();
  final deviceUUID = await getDeviceUUID();
final deviceCode = deviceUUID.replaceAll('-', '').substring(0, 4);
  // Guard against empty or default name
  if (displayName.isEmpty || displayName == 'App User') {
    // Use first 8 chars of UUID as fallback name
    final fallback = deviceUUID.replaceAll('-', '').substring(0, 8);
    final broadcastName = '$fallback#$deviceCode';
    debugPrint("BEACON: No name set — using fallback '$broadcastName'");
    return broadcastName;
  }

  // Trim name to max 8 chars
  final trimmed = displayName.length > 8 
      ? displayName.substring(0, 8) 
      : displayName;
  
  // Final broadcast name: "Mridul#6d36"
  final broadcastName = '$trimmed#$deviceCode';
  debugPrint("BEACON: Broadcast name = '$broadcastName' (${broadcastName.length} chars)");
  return broadcastName;
}

 static Future<bool> startAdvertising() async {
  final status = await Permission.bluetoothAdvertise.request();
  debugPrint("BEACON: Permission = $status");
  if (!status.isGranted) return false;

  // Build broadcast name once before retry loop
  final broadcastName = await _buildBroadcastName();
  debugPrint("BEACON: Broadcasting as '$broadcastName'");

  for (int attempt = 1; attempt <= 5; attempt++) {
    try {
      final currentState = _peripheral.state;
      debugPrint("BEACON: Attempt $attempt state = $currentState");

      if (currentState != BluetoothLowEnergyState.poweredOn) {
        debugPrint("BEACON: Not ready, waiting...");
        await Future.delayed(const Duration(milliseconds: 1000));
        continue;
      }

      // Single Advertisement object inside loop after state check passes
      final advertisement = Advertisement(
        serviceUUIDs: [UUID.fromString(APP_SERVICE_UUID)],
        name: broadcastName,
      );

      await _peripheral.startAdvertising(advertisement);
      debugPrint("BEACON: Broadcasting started successfully");
      return true;

    } catch (e) {
      debugPrint("BEACON: Attempt $attempt failed = $e");
      if (attempt < 5) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
  }

  debugPrint("BEACON: All attempts failed");
  return false;
}

  static Future<void> setDisplayName(String name) async {
  // Guard against empty names
  if (name.trim().isEmpty) {
    debugPrint("BEACON: Refused to save empty display name");
    return; // don't save empty strings
  }
  _displayName = name.trim();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('display_name', name.trim());
  debugPrint("BEACON: Display name set to '$name'");
}

static Future<String> getDisplayName() async {
  if (_displayName != null && _displayName!.isNotEmpty) return _displayName!;
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('display_name');
  if (saved != null && saved.trim().isNotEmpty) return saved;
   final uuid = await getDeviceUUID();
  return "User-${uuid.substring(0,8)}";
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