import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_plugin_learning/flutter_plugin_learning.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FlutterPluginLearning _battery = FlutterPluginLearning();

  String _batteryState;
  int _batteryLevel;
  StreamSubscription<BatteryState> _batteryStateSubscription;

  @override
  void initState() {
    super.initState();
    _batteryStateSubscription =
        _battery.onBatteryStateChanged.listen((BatteryState state) {
      String batteryState = 'UnKnow';
      switch (state) {
        case BatteryState.full:
          batteryState = '已充满';
          break;
        case BatteryState.charging:
          batteryState = '充电中';
          break;
        case BatteryState.discharging:
          batteryState = '未充电';
          break;
        default:
      }
      setState(() {
        _batteryState = batteryState;
      });
    });

    _battery.batteryLevel.then((int batteryLevel) {
      setState(() {
        _batteryLevel = batteryLevel;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    if (_batteryStateSubscription != null) {
      _batteryStateSubscription.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('电池状态为：$_batteryState'),
              SizedBox(height: 10),
              Text('电池容量为：$_batteryLevel%'),
            ],
          ),
        ),
      ),
    );
  }
}
