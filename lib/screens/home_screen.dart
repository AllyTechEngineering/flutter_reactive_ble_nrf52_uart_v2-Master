import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

// This flutter app demonstrates an usage of the flutter_reactive_ble flutter plugin
// This app works only with BLE devices which advertise with a Nordic UART Service (NUS) UUID
// Uuid _UART_UUID = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
Uuid _UART_UUID = Uuid.parse('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
Uuid _UART_RX = Uuid.parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
Uuid _UART_TX = Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

class HomeScreen extends StatefulWidget {
  final String textTitle;
  HomeScreen({super.key, required this.textTitle});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final flutterReactiveBle = FlutterReactiveBle();
  List<DiscoveredDevice> _foundBleUARTDevices = [];
  late StreamSubscription<DiscoveredDevice> _scanStream;
  late Stream<ConnectionStateUpdate> _currentConnectionStream;
  late StreamSubscription<ConnectionStateUpdate> _connection;
  late QualifiedCharacteristic _txCharacteristic;
  late QualifiedCharacteristic _rxCharacteristic;
  late Stream<List<int>> _receivedDataStream;
  late TextEditingController _dataToSendText;
  bool _scanning = false;
  bool _connected = false;
  String _logTexts = "";
  List<String> _receivedData = [];
  int _numberOfMessagesReceived = 0;

  void initState() {
    super.initState();
    _dataToSendText = TextEditingController();
  }

  void refreshScreen() {
    setState(() {});
  }

  void _sendData() async {
    await flutterReactiveBle.writeCharacteristicWithResponse(_rxCharacteristic,
        value: _dataToSendText.text.codeUnits);
  }

  void onNewReceivedData(List<int> data) {
    _numberOfMessagesReceived += 1;
    _receivedData.add("$_numberOfMessagesReceived: ${String.fromCharCodes(data)}");
    if (_receivedData.length > 5) {
      _receivedData.removeAt(0);
    }
    refreshScreen();
  }

  void _disconnect() async {
    await _connection.cancel();
    _connected = false;
    refreshScreen();
  }

  void _stopScan() async {
    await _scanStream.cancel();
    _scanning = false;
    refreshScreen();
  }

  Future<void> showNoPermissionDialog() async => showDialog<void>(
        context: context,
        barrierDismissible: false, // user must tap button!
        builder: (BuildContext context) => AlertDialog(
          title: const Text('No location permission '),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('No location permission granted.'),
                const Text('Location permission is required for BLE to function.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Acknowledge'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );

  void _startScan() async {
    bool goForIt = false;
    PermissionStatus permission;
    if (Platform.isAndroid) {
      // permission = await LocationPermissions().requestPermissions();
      permission = await Permission.bluetooth.status;
      if (permission == PermissionStatus.granted) goForIt = true;
    } else if (Platform.isIOS) {
      print('Inside of else if for Platform.isIOS:');
      goForIt = true;
    }
    if (goForIt) {
      _foundBleUARTDevices = [];
      _scanning = true;
      refreshScreen();
      _scanStream = flutterReactiveBle.scanForDevices(withServices: [_UART_UUID]).listen((device) {
        if (_foundBleUARTDevices.every((element) => element.id != device.id)) {
          _foundBleUARTDevices.add(device);
          refreshScreen();
        }
      }, onError: (Object error) {
        _logTexts = "${_logTexts}ERROR while scanning:$error \n";
        refreshScreen();
      });
    } else {
      await showNoPermissionDialog();
    }
  }

  void onConnectDevice(index) {
    print('First line of onConnectedDevice');
    // _currentConnectionStream = flutterReactiveBle.connectToAdvertisingDevice(
    //   id: _foundBleUARTDevices[index].id,
    //   prescanDuration: Duration(seconds: 2),
    //   withServices: [_UART_UUID, _UART_RX, _UART_TX],
    //   // withServices: [_UART_UUID],
    // );
    _currentConnectionStream = flutterReactiveBle.connectToDevice(
      id: _foundBleUARTDevices[index].id,
      servicesWithCharacteristicsToDiscover: {
        _UART_UUID: [_UART_RX, _UART_TX]
      },
      connectionTimeout: const Duration(seconds: 2),
    );
    _logTexts = "";
    refreshScreen();
    _connection = _currentConnectionStream.listen((event) {
      print(
          ' _connection = _currentConnectionStream - event.connectionState: ${event.connectionState}');
      var id = event.deviceId.toString();
      switch (event.connectionState) {
        case DeviceConnectionState.connecting:
          {
            _logTexts = "${_logTexts}Connecting to $id\n";
            print('case DeviceConnectionState.connecting: $_logTexts');
            break;
          }
        case DeviceConnectionState.connected:
          {
            _connected = true;
            _logTexts = "${_logTexts}Connected to $id\n";
            print('DeviceConnectionState.connected: $_logTexts');
            _numberOfMessagesReceived = 0;
            _receivedData = [];
            _txCharacteristic = QualifiedCharacteristic(
                serviceId: _UART_UUID, characteristicId: _UART_TX, deviceId: event.deviceId);
            _receivedDataStream = flutterReactiveBle.subscribeToCharacteristic(_txCharacteristic);
            _receivedDataStream.listen((data) {
              onNewReceivedData(data);
            }, onError: (dynamic error) {
              _logTexts = "${_logTexts}Error:$error$id\n";
              print('onNewReceivedData(data) error: $_logTexts');
            });
            _rxCharacteristic = QualifiedCharacteristic(
                serviceId: _UART_UUID, characteristicId: _UART_RX, deviceId: event.deviceId);
            break;
          }
        case DeviceConnectionState.disconnecting:
          {
            _connected = false;
            _logTexts = "${_logTexts}Disconnecting from $id\n";
            print('DeviceConnectionState.disconnecting: $_logTexts');
            break;
          }
        case DeviceConnectionState.disconnected:
          {
            _logTexts = "${_logTexts}Disconnected from $id\n";
            print('DeviceConnectionState.disconnected: $_logTexts');
            break;
          }
      }
      refreshScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.textTitle,
          style: GoogleFonts.roboto(
              textStyle: Theme.of(context).textTheme.titleMedium, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Text(
                  "nrf52 UART BLE Found:",
                  style: GoogleFonts.roboto(
                    textStyle: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Container(
                  /// TODO change the height based on media query and orientation
                  height: 100.0,
                  margin: const EdgeInsets.all(3.0),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue, width: 2)),
                  child: ListView.builder(
                    itemCount: _foundBleUARTDevices.length,
                    itemBuilder: (context, index) => Card(
                      child: ListTile(
                        tileColor: Colors.white,
                        dense: false,
                        enabled: true,
                        // !((!_connected && _scanning) || (!_scanning && _connected)),
                        trailing: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            // (!_connected && _scanning) || (!_scanning && _connected) ? () {} :
                            (!_scanning && _connected) ? () {} : onConnectDevice(index);
                            // print('At the end of the onTap to connect to the device: $index');
                            // print('Status of _connected: $_connected');
                            // print('Status of _scanning: $_scanning');
                          },
                          child: Container(
                            /// TODO change the height based on media query and orientation
                            height: 100.0,
                            width: 48,
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.add_link,
                              size: 30.0,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        subtitle: Text(
                          _foundBleUARTDevices[index].id,
                          style:
                              GoogleFonts.roboto(textStyle: Theme.of(context).textTheme.bodySmall),
                        ),
                        title: Text(
                          "$index: ${_foundBleUARTDevices[index].name}",
                          style:
                              GoogleFonts.roboto(textStyle: Theme.of(context).textTheme.bodySmall),
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  "Status messages:",
                  style: GoogleFonts.roboto(textStyle: Theme.of(context).textTheme.bodyMedium),
                ),
                Container(
                  /// TODO change the height based on media query and orientation
                  height: 100.0,
                  margin: const EdgeInsets.all(3.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _logTexts,
                          style:
                              GoogleFonts.roboto(textStyle: Theme.of(context).textTheme.bodySmall),
                          softWrap: true,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  "Received data:",
                  style: GoogleFonts.roboto(textStyle: Theme.of(context).textTheme.bodyMedium),
                ),
                Container(
                  /// TODO change the height based on media query and orientation
                  height: 100.0,
                  margin: const EdgeInsets.all(3.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _receivedData.join("\n"),
                      style: GoogleFonts.roboto(textStyle: Theme.of(context).textTheme.bodySmall),
                    ),
                  ),
                ),
                Text(
                  "Send message:",
                  style: GoogleFonts.roboto(textStyle: Theme.of(context).textTheme.bodyMedium),
                ),
                Container(
                  /// TODO change the height based on media query and orientation
                  height: 100.0,
                  margin: const EdgeInsets.all(3.0),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue, width: 2)),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          style:
                              GoogleFonts.roboto(textStyle: Theme.of(context).textTheme.bodyMedium),
                          enabled: _connected,
                          controller: _dataToSendText,
                          decoration: InputDecoration(
                              hintStyle: TextStyle(fontSize: 10.0, color: Colors.grey),
                              fillColor: Colors.white,
                              border: InputBorder.none,
                              hintText: 'Enter a string'),
                        ),
                      ),
                      TextButton(
                          child: Icon(
                            Icons.send,
                            size: 40.0,
                            color: _connected ? Colors.blue : Colors.grey,
                          ),
                          onPressed: _connected ? _sendData : () {}),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      /// TODO change this so that height and layout are based on media query and orientation
      persistentFooterButtons: [
        Container(
          height: 35,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (_scanning)
                Text(
                  "Scanning: Scanning",
                  style: GoogleFonts.roboto(textStyle: Theme.of(context).textTheme.titleSmall),
                )
              else
                Text(
                  "Scanning: Idle",
                  style: GoogleFonts.roboto(textStyle: Theme.of(context).textTheme.titleSmall),
                ),
              if (_connected)
                Text(
                  "Connected",
                  style: GoogleFonts.roboto(textStyle: Theme.of(context).textTheme.titleSmall),
                )
              else
                Text(
                  "disconnected.",
                  style: GoogleFonts.roboto(textStyle: Theme.of(context).textTheme.titleSmall),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: !_scanning && !_connected ? _startScan : () {},
          child: Icon(
            Icons.play_arrow,
            color: !_scanning && !_connected ? Colors.blue : Colors.grey,
          ),
        ),
        TextButton(
            onPressed: _scanning ? _stopScan : () {},
            child: Icon(
              Icons.stop,
              color: _scanning ? Colors.blue : Colors.grey,
            )),
        TextButton(
          onPressed: _connected ? _disconnect : () {},
          child: Icon(
            Icons.cancel,
            color: _connected ? Colors.blue : Colors.grey,
          ),
        ),
      ],
    );
  } //widget build
} //class
