// import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_reactive_ble_nrf52_uart_v2/screens/home_screen.dart';
import 'package:flutter_reactive_ble_nrf52_uart_v2/utilities/theme.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'dart:io' show Platform;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

// utilities
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter_reactive_ble nrf52DK UART',
      theme: appTheme,
      home: HomeScreen(
        textTitle: 'Flutter_reactive_ble nrf52DK UART',
      ),
    );
  }
}
