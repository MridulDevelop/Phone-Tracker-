import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'dart:async';
import 'beacon_survice.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phone Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const MyHomePage(title: 'Phone Tracker'),
      themeMode: ThemeMode.dark,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  // ── Subscriptions ──────────────────────────────────────
  StreamSubscription? _scanSubscription;
  StreamSubscription? _bluetoothStateSubscription;
  StreamSubscription? _isScanningSubscription;

  // ── State ──────────────────────────────────────────────
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  bool isAdvertising = false;
  ScanResult? pinnedDevice;

  // ── Search ─────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // ── Filtered list ──────────────────────────────────────
  List<ScanResult> get filteredResults {
    if (_searchQuery.isEmpty) return scanResults;
    return scanResults.where((r) =>
      getDeviceLabel(r).toLowerCase()
          .contains(_searchQuery.toLowerCase()) ||
      r.device.remoteId.toString().toLowerCase()
          .contains(_searchQuery.toLowerCase())
    ).toList();
  }

  // ── Distance calculation ───────────────────────────────
  double calculateDist(int rssi) {
    int measuredPower = -59;
    double environmentalFactor = 2.0;
    num distance = pow(
      10, ((measuredPower - rssi) / (10 * environmentalFactor))
    );
    return distance.toDouble();
  }

  // ── App device detection ───────────────────────────────
  // Checks if a scanned device is running your app
  // by looking for your service UUID FFFE in its advertisement
  bool isAppDevice(ScanResult result) {
    return result.advertisementData.serviceUuids
        .any((uuid) => uuid.toString()
            .toLowerCase()
            .contains('fffe'));
  }

  // ── Device label ───────────────────────────────────────
  // Returns correct display name for any device type
  String getDeviceLabel(ScanResult result) {
    if (isAppDevice(result)) return "📡 App User";
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }
    return result.device.remoteId.toString();
  }

  // ── Lifecycle ──────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    bluetoothState();
    isScanningState();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _bluetoothStateSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Bluetooth on/off listener ──────────────────────────
  void bluetoothState() {
    _bluetoothStateSubscription =
        FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) async {
      debugPrint("Bluetooth state: $state");
      if (state == BluetoothAdapterState.off) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
          debugPrint("User refused to turn on Bluetooth: $e");
        }
      }
    });
  }

  // ── isScanning stream listener ─────────────────────────
  void isScanningState() {
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) setState(() => isScanning = scanning);
    });
  }

  // ── Start scan ─────────────────────────────────────────
  void _startScan() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Check mounted after every await
    if (!mounted) return;

    if (statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.location]!.isGranted) {

      await _scanSubscription?.cancel();

      setState(() {
        scanResults.clear();
        isScanning = true; // optimistic update
      });

      _scanSubscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          if (!mounted) return;

          // Debug — shows service UUIDs of all detected devices
          for (var r in results) {
            if (r.advertisementData.serviceUuids.isNotEmpty) {
              debugPrint("SCAN: ${r.device.remoteId} → "
                  "UUIDs: ${r.advertisementData.serviceUuids}");
            }
          }

          setState(() {
            scanResults = results.toList();

            // Keep pinned device RSSI updated in real time
            if (pinnedDevice != null) {
              final updated = results.where((r) =>
                  r.device.remoteId == pinnedDevice!.device.remoteId);
              if (updated.isNotEmpty) pinnedDevice = updated.first;
            }
          });
        },
        onError: (error) {
          debugPrint("Scan error: $error");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Scan error: $error"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );

      await FlutterBluePlus.startScan(continuousUpdates: true);

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bluetooth and Location permissions are required!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Stop scan ──────────────────────────────────────────
  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (mounted) setState(() {});
  }

  // ── Toggle broadcasting ────────────────────────────────
  Future<void> _toggleAdvertising() async {
    if (isAdvertising) {
      await BeaconService.stopAdvertising();
      if (mounted) setState(() => isAdvertising = false);
    } else {
      final success = await BeaconService.startAdvertising();
      if (mounted) {
        setState(() => isAdvertising = success);
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Broadcasting failed on this device"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Phone Tracker'),

        // Broadcast toggle — top right
        actions: [
          IconButton(
            tooltip: isAdvertising
                ? 'Stop Broadcasting'
                : 'Start Broadcasting',
            icon: Icon(
              isAdvertising
                  ? Icons.wifi_tethering
                  : Icons.wifi_tethering_off,
              color: isAdvertising ? Colors.green : null,
            ),
            onPressed: _toggleAdvertising,
          ),
        ],

        // Search bar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: "Search by name or MAC address...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),

      body: Column(
        children: [

          // ── Pinned device card ───────────────────────
          if (pinnedDevice != null)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(
                  Icons.location_on,
                  color: Colors.amber,
                ),
                title: Text(
                  getDeviceLabel(pinnedDevice!),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  pinnedDevice!.device.remoteId.toString(),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${calculateDist(pinnedDevice!.rssi).toStringAsFixed(1)}m",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    Text(
                      "${pinnedDevice!.rssi} dBm",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                onTap: () => setState(() => pinnedDevice = null),
              ),
            ),

          // ── Device list ──────────────────────────────
          Expanded(
            child: filteredResults.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No devices match "$_searchQuery"'
                          : "No devices found.\nTap the search button to scan.",
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredResults.length,
                    itemBuilder: (context, index) {
                      final data = filteredResults[index];
                      final isPinned = pinnedDevice?.device.remoteId ==
                          data.device.remoteId;
                      final appDevice = isAppDevice(data);
                      double distanceInMeters = calculateDist(data.rssi);

                      Color signalColor;
                      if (distanceInMeters < 2.0) {
                        signalColor = Colors.green;
                      } else if (distanceInMeters < 5.0) {
                        signalColor = Colors.yellow;
                      } else {
                        signalColor = Colors.red;
                      }

                      return ListTile(
                        onTap: () {
                          setState(() {
                            pinnedDevice = isPinned ? null : data;
                          });
                        },
                        leading: Icon(
                          isPinned
                              ? Icons.push_pin
                              : appDevice
                                  ? Icons.smartphone
                                  : Icons.bluetooth,
                          color: isPinned
                              ? Colors.amber
                              : appDevice
                                  ? Colors.green
                                  : null,
                        ),
                        title: Text(getDeviceLabel(data)),
                        subtitle: Text(
                          data.device.remoteId.toString(),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${distanceInMeters.toStringAsFixed(2)}m",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: signalColor,
                              ),
                            ),
                            Text(
                              "${data.rssi} dBm",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // ── FAB ───────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (isScanning) {
            await _stopScan();
          } else {
            _startScan();
          }
        },
        tooltip: isScanning ? 'Stop Scanning' : 'Start Scanning',
        backgroundColor: isScanning ? Colors.red : Colors.blue,
        child: Icon(
          isScanning ? Icons.stop : Icons.search,
          color: Colors.white,
        ),
      ),
    );
  }
}