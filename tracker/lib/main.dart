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

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phone Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark,), 
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
  
  StreamSubscription? _scanSubscription;
  StreamSubscription? _bluetoothStateSubscription;
  StreamSubscription? _isScanningSubscription;

double calculateDist(int rssi){
int measuredPower = -59;
double environmentalFactor = 2.0;
num distance = pow(10,((measuredPower - rssi)/(10*environmentalFactor)));
return distance.toDouble();
}

List<ScanResult> scanResults = [];
  bool isScanning = false;
  bool isAdvertising = false;
// search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
// pinning
  ScanResult? pinnedDevice;
 // Filtered search
  List<ScanResult> get filteredResults {
    if (_searchQuery.isEmpty) return scanResults;
    return scanResults.where((r) =>
      r.device.platformName.toLowerCase()
          .contains(_searchQuery.toLowerCase()) ||
      r.device.remoteId.toString().toLowerCase()
          .contains(_searchQuery.toLowerCase())
    ).toList();
  }

  void _startScan() async {
    // 1. Ask for Android Permissions safely
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
     //At the start of startscan to keep the isScanningSubscription in sync.
      setState(()=> isScanning = true);
      await FlutterBluePlus.startScan(continuousUpdates: true);

     if (!mounted) return;

    // 2. If user clicks "Allow", start scanning
    if (statuses[Permission.bluetoothScan]!.isGranted && 
        statuses[Permission.location]!.isGranted) {
      
      await _scanSubscription?.cancel(); 

      setState(() {
        scanResults.clear(); 
        isScanning = true;
      });

    _scanSubscription = FlutterBluePlus.onScanResults.listen((results){
        if(!mounted) return;
        setState(() {
          scanResults = results.toList();
           
           // Keep pinned device RSSI updated in real time
            if (pinnedDevice != null) {
              final updated = results.where((r) =>
                r.device.remoteId == pinnedDevice!.device.remoteId
              );
              if (updated.isNotEmpty) {
                pinnedDevice = updated.first;
              }
            }
          });
    },
        onError : (error){
          debugPrint("Scan error: $error");
          if(mounted){
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Scan error: $error"),
              backgroundColor: Colors.red,),
            );
          }
        }); 
       await FlutterBluePlus.startScan(continuousUpdates: true);
    }
    else {
      //  Show error if permissions denied
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bluetooth and Location permissions are required!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _stopScan() async {
  await FlutterBluePlus.stopScan();
  await _scanSubscription?.cancel();
  _scanSubscription = null;
  if(mounted) setState(() {});
  }

// toggle broadcasting
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
              content: Text("Broadcasting not supported on this device"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override  //This is the function which call bluetooth permision box at start  
  void initState(){
    super.initState();
    bluetoothState();
    isScanningState();
  }
  @override //This is the function that disposes the _scanSubscription at the end 
  void dispose(){
  FlutterBluePlus.stopScan();
   _scanSubscription?.cancel();
   _bluetoothStateSubscription?.cancel();
   _isScanningSubscription?.cancel();
   _searchController.dispose();
  super.dispose();
  }

   void isScanningState(){
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning){
      setState((){
        isScanning = scanning;
      });
    });
   }

   void bluetoothState() {
   _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) async {
    debugPrint("Current Bluetooth State: $state");
    
    if (state == BluetoothAdapterState.off) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        debugPrint("User refused to turn on Bluetooth: $e");
      }
    } else if (state == BluetoothAdapterState.on) {
      debugPrint("Bluetooth is ready!");
    }
  });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        // Broadcast toggle lives here — top right
        actions: [
          IconButton(
            tooltip: isAdvertising ? 'Stop Broadcasting' : 'Start Broadcasting',
            icon: Icon(
              isAdvertising
                  ? Icons.wifi_tethering
                  : Icons.wifi_tethering_off,
              color: isAdvertising ? Colors.green : null,
            ),
            onPressed: _toggleAdvertising,
          ),
        ],
          // Search bar inside AppBar at the bottom
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

     body:  Column(
        children: [

          // ── Pinned device card ───────────────────────
          if (pinnedDevice != null)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.location_on, color: Colors.amber),
                title: Text(
                  pinnedDevice!.device.platformName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(pinnedDevice!.device.remoteId.toString()),
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
                // Tap pinned card to unpin
                onTap: () => setState(() => pinnedDevice = null),
              ),
            ),
            // Device List
           Expanded(child: filteredResults.isEmpty? 
           Center( child: Text(_searchQuery.isNotEmpty? 'No Devices Match "$_searchQuery"'
           : "No Devices Found. \nTap the search buuton to scan.",
            textAlign: TextAlign.center,
           ),
           )
          : ListView.builder(
              itemCount: filteredResults.length,
              itemBuilder: (context, index) {
                final data = filteredResults[index];
                final isPinned = pinnedDevice?.device.remoteId == data.device.remoteId;
                double distanceinMeters = calculateDist(data.rssi);

                Color signalColor;
                if(distanceinMeters < 2.0){
                  signalColor = Colors.green;
                } else if (distanceinMeters < 5.0){
                  signalColor = Colors.yellow;
                }else{
                  signalColor = Colors.red;
                }

                return ListTile(
                   // Tap to pin or unpin
                        onTap: () {
                          setState(() {
                            pinnedDevice = isPinned ? null : data;
                          });
                        },
                        leading: Icon(
                          isPinned ? Icons.push_pin : Icons.bluetooth,
                          color: isPinned ? Colors.amber : null,
                        ),
                        title: Text(data.device.platformName),
                        subtitle: Text(data.device.remoteId.toString()),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${distanceinMeters.toStringAsFixed(2)}m",
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
                 
      floatingActionButton: FloatingActionButton(
        onPressed: () async{
          if(isScanning){
            await _stopScan();
          } else{
            _startScan();
          }
        },
        tooltip: isScanning ? 'Stop Scanning': 'Start Scanning',
        backgroundColor: isScanning ? Colors.red : Colors.blue,

        child: Icon(
          isScanning ? Icons.stop : Icons.search,
          color: Colors.white,
          ),
        ),
      );
  }
}
