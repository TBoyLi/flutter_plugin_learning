import 'dart:async';

import 'package:flutter/services.dart';

enum BatteryState {
  /// The battery is completely full of energy.
  full,

  /// The battery is currently storing energy.
  charging,

  /// The battery is currently losing energy.
  discharging
}

class FlutterPluginLearning {
  factory FlutterPluginLearning() {
    if (_instance == null) {
      final MethodChannel methodChannel =
          const MethodChannel('plugins.limit.io/battery');
      final EventChannel eventChannel =
          const EventChannel('plugins.limit.io/charging');
      _instance = FlutterPluginLearning.init(methodChannel, eventChannel);
    }
    return _instance;
  }

  FlutterPluginLearning.init(this._methodChannel, this._eventChannel);

  static FlutterPluginLearning _instance;

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  Stream<BatteryState> _onBatteryStateChanged;

  // static Future<int> get getBatteryLevel async {
  //   final int batteryLevel = await _methodChannel.invokeMethod('getBatteryLevel');
  //   return batteryLevel;
  // }

  Future<int> get batteryLevel => _methodChannel
      .invokeMethod<int>('getBatteryLevel')
      .then<int>((dynamic result) => result);

  Stream<BatteryState> get onBatteryStateChanged {
    if (_onBatteryStateChanged == null) {
      _onBatteryStateChanged = _eventChannel
          .receiveBroadcastStream()
          .map((dynamic event) => _parseBatteryState(event));
    }
    return _onBatteryStateChanged;
  }

  BatteryState _parseBatteryState(String state) {
    switch (state) {
      case 'full':
        return BatteryState.full;
      case 'charging':
        return BatteryState.charging;
      case 'discharging':
        return BatteryState.discharging;
      default:
        throw ArgumentError('$state is not a valid BatteryState.');
    }
  }
}
