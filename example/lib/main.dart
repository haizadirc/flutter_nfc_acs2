import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_acs2/flutter_nfc_acs.dart';
import 'package:flutter_nfc_acs2/models.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter NFC ACS Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const DeviceListScreen(),
    );
  }
}

class DeviceListScreen extends StatelessWidget {
  const DeviceListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter NFC ACS Devices'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<AcsDevice>>(
        stream: FlutterNfcAcs.devices,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error scanning devices: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning for ACS Bluetooth devices...'),
                ],
              ),
            );
          }

          final devices = snapshot.data ?? [];
          if (devices.isEmpty) {
            return const Center(
              child: Text('No Bluetooth ACS devices found yet.\nMake sure Bluetooth is enabled.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: devices.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final device = devices[i];
              return ListTile(
                leading: const Icon(Icons.bluetooth_searching, color: Colors.blue),
                title: Text(device.name ?? 'Unknown Device'),
                subtitle: Text(device.address),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceRoute(device: device),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class DeviceRoute extends StatefulWidget {
  const DeviceRoute({Key? key, required this.device}) : super(key: key);

  final AcsDevice device;

  @override
  State<DeviceRoute> createState() => _DeviceRouteState();
}

class _DeviceRouteState extends State<DeviceRoute> {
  String connection = FlutterNfcAcs.DISCONNECTED;
  String? error;
  StreamSubscription<String>? _statusSub;

  @override
  void initState() {
    super.initState();

    _connect();

    _statusSub = FlutterNfcAcs.connectionStatus.listen((status) {
      if (mounted) {
        setState(() {
          connection = status;
        });
      }
    });
  }

  void _connect() {
    setState(() {
      error = null;
    });
    FlutterNfcAcs.connect(widget.device.address).catchError((err) {
      if (mounted) {
        setState(() {
          error = err.toString();
        });
      }
    });
  }

  void _disconnect() {
    FlutterNfcAcs.disconnect().catchError((err) {
      if (mounted) {
        setState(() {
          error = err.toString();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = connection == FlutterNfcAcs.CONNECTED;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name ?? 'ACS Device'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      widget.device.name ?? 'Unknown Device',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.device.address,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    Chip(
                      label: Text(
                        'Status: $connection',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: isConnected ? Colors.green[100] : Colors.amber[100],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(isConnected ? Icons.bluetooth_disabled : Icons.bluetooth_connected),
              label: Text(isConnected ? 'Disconnect Reader' : 'Connect Reader'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: isConnected ? Colors.red[600] : Colors.blue[600],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (isConnected) {
                  _disconnect();
                } else {
                  _connect();
                }
              },
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.battery_charging_full),
                title: const Text('Battery Status'),
                subtitle: StreamBuilder<int>(
                  stream: FlutterNfcAcs.batteryStatus,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text('${snapshot.data}%');
                    }
                    return const Text('Waiting for battery info...');
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.nfc),
                title: const Text('Scanned NFC Card'),
                subtitle: StreamBuilder<String>(
                  stream: FlutterNfcAcs.cards,
                  builder: (context, snapshot) {
                    switch (snapshot.connectionState) {
                      case ConnectionState.none:
                        return const Text('No connection');
                      case ConnectionState.waiting:
                        return const Text('Tap an NFC card on reader...');
                      case ConnectionState.active:
                        return Text(
                          snapshot.data ?? 'No data',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        );
                      case ConnectionState.done:
                        return const Text('Session complete');
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    FlutterNfcAcs.disconnect();
    super.dispose();
  }
}
