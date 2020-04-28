## 前言

我们都知道Flutter开发的app是可以同时在iOS和Android系统上运行的。显然Flutter需要有和Native通信的能力。在实际项目中，Flutter并不能全面满足项目需求，比如获取一些硬件信息（如电池电量），这些都是一些比较简单的Native需求，Flutter官方也给出了一些比较[常用的Plugin](https://github.com/flutter/plugins)。但在实际项目中可能需求就没那么简单了，比如融云通讯、环信通讯，再或者项目自定义的需求，这可能就需要我们自己去写插件了。这里我就以Flutter获取Native电池电量和电池状态（充电中、充满电、未充电）为例（包括IOS-Swift 和 Android-Kotlin）来实现自己的需求。

## 思路

Flutter是如何做到的呢？当然是Flutter官方给的Platform Channels。如图：


![](https://user-gold-cdn.xitu.io/2020/4/28/171bea95ce70ce3b?w=580&h=647&f=png&s=40194)

上图来自Flutter官网，表明了Platform Channels的架构示意图。Platform Channel包括MethodChannel、EventChannel和BasicMessageChannel三大通道。

## Platform Channel 支持的数据类型
比较常用
Dart | iOS-Swift |  Android-Kotlin
-|-|-
null | nil | null |
bool | Bool | Boolean |
int | Int | Int |
float | Int | Int |
double | Double | Double |
String | String | String |
List | Array | List |
Map | Dictionary | HashMap |

## MethodChannel

俗称方法通道（个人见解）用于传递方法调用

以 Flutter 获取 手机电量为例, 在 Flutter 界面中要想获取 Android/iOS 的电量, 首先要在 Native 编写获取电量的功能, 供 Flutter 来调用。

- **Native - iOS**
```
public class SwiftFlutterPluginLearningPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftFlutterPluginLearningPlugin()
        let methodChannel = FlutterMethodChannel(name: "plugins.limit.io/battery", binaryMessenger: registrar.messenger())
        //注册电池（plugins.limit.io/battery）方法通道
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getBatteryLevel":
            let batterLevel = getBatteryLevel()
            if(batterLevel == -1) {
                result(FlutterError(code: "UNAVAILABLE", message: "Battery info unavailable", details: nil));
            } else {
                result(batterLevel)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    //获取电池电量
    private func getBatteryLevel() -> Float {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        if device.batteryState == .unknown {
            return -1;
        } else {
            return UIDevice.current.batteryLevel
        }
    }
}

```
- **Native - Android**
```
public class FlutterPluginLearningPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private var applicationContext: Context? = null

    /**
     * 方法通道
     */
    private var methodChannel: MethodChannel? = null

    /**
     * 连接到引擎
     */
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        onAttachedToEngine(flutterPluginBinding.applicationContext, flutterPluginBinding.binaryMessenger)
    }

    private fun onAttachedToEngine(applicationContext: Context, messenger: BinaryMessenger) {
        this.applicationContext = applicationContext
        methodChannel = MethodChannel(messenger, "plugins.limit.io/battery")
        methodChannel?.setMethodCallHandler(this)
    }

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val instance = FlutterPluginLearningPlugin()
            instance.onAttachedToEngine(registrar.context(), registrar.messenger())
        }
    }

    /**
     * 回调方法
     */
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (call.method == "getBatteryLevel") {
            val batterLevel = getBatteryLevel()
            if (batterLevel != -1) {
              result.success(batterLevel)
            } else {
              result.error("UNAVAILABLE", "Battery level not available.", null);
            }
        } else {
            result.notImplemented()
        }
    }

    /**
     * 从引擎中脱离
     */
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }

    /**
     * 获取电池电量方法
     */
    private fun getBatteryLevel(): Int {
        var batteryLevel = -1
        batteryLevel = if (VERSION.SDK_INT >= VERSION_CODES.LOLLIPOP) {
            val batteryManager = applicationContext?.let { getSystemService(it, BatteryManager::class.java) }
            batteryManager!!.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } else {
            val intent = ContextWrapper(applicationContext).registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) * 100 / intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        }

        return batteryLevel
    }
}
```
- **Flutter**

*flutter 插件*
```
class FlutterPluginLearning {
  factory FlutterPluginLearning() {
    if (_instance == null) {
      final MethodChannel methodChannel =
          const MethodChannel('plugins.limit.io/battery');
      _instance = FlutterPluginLearning.init(methodChannel);
    }
    return _instance;
  }

  FlutterPluginLearning.init(this._methodChannel);

  static FlutterPluginLearning _instance;

  final MethodChannel _methodChannel;

  Future<int> get batteryLevel => _methodChannel
      .invokeMethod<int>('getBatteryLevel')
      .then<int>((dynamic result) => result);
}

```
*flutter 调用*
```
FlutterPluginLearning _battery = FlutterPluginLearning();
_battery.batteryLevel.then((int batteryLevel) {
      //to do something you want
});
```


## EventChannel

俗称流通道（个人见解）用于数据流（event streams）的通信
以 Flutter 获取 手机电池状态为例, 在 Flutter 界面中要想获取 Android/iOS 的电池状态, 首先要在 Native 编写获取电池状态的功能, 供 Flutter 来调用。

- **Native - iOS**
```
public class SwiftFlutterPluginLearningPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    var eventSink: FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftFlutterPluginLearningPlugin()
        let evenChannel = FlutterEventChannel(name: "plugins.limit.io/charging", binaryMessenger: registrar.messenger())
        evenChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        UIDevice.current.isBatteryMonitoringEnabled = true
        self.sendBatteryStateEvent()
        NotificationCenter.default.addObserver(self, selector: #selector(onBatteryStateDidChange(notification:)), name: UIDevice.batteryStateDidChangeNotification, object: nil)
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(self)
        eventSink = nil
        return nil
    }
    
    @objc private func onBatteryStateDidChange(notification: NSNotification?) {
        self.sendBatteryStateEvent()
    }
    
    private func sendBatteryStateEvent() {
        if eventSink == nil {
            return
        }
        let state = UIDevice.current.batteryState
        switch state {
        case .full:
            eventSink!("full")
            break
        case .charging:
            eventSink!("charging")
            break
        case .unplugged:
            eventSink!("unplugged")
            break
        default:
            eventSink!(FlutterError(code: "UNAVAILABLE", message: "Charging status unavailable", details: nil))
            break
        }
    }
}

```
- **Native - Android**
```
public class FlutterPluginLearningPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private var applicationContext: Context? = null

    /**
     * 事件流通道
     * Native 需要频繁的发送消息给 Flutter, 比如监听网络状态, 蓝牙设备等等然后发送给 Flutter
     */
    private var eventChannel: EventChannel?= null

    private var chargingStateChangeReceiver: BroadcastReceiver? = null

    /**
     * 连接到引擎
     */
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        onAttachedToEngine(flutterPluginBinding.applicationContext, flutterPluginBinding.binaryMessenger)
    }

    private fun onAttachedToEngine(applicationContext: Context, messenger: BinaryMessenger) {
        this.applicationContext = applicationContext
        eventChannel = EventChannel(messenger, "plugins.limit.io/charging")
        eventChannel?.setStreamHandler(this)
    }

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val instance = FlutterPluginLearningPlugin()
            instance.onAttachedToEngine(registrar.context(), registrar.messenger())
        }
    }

    /**
     * 回调方法
     */
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        
    }

    /**
     * 从引擎中脱离
     */
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
    }

    /**
     * 监听
     */
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        chargingStateChangeReceiver = createChargingStateChangeReceiver(events)
        applicationContext?.registerReceiver(chargingStateChangeReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    }

    /**
     * 取消监听
     */
    override fun onCancel(arguments: Any?) {
        applicationContext?.unregisterReceiver(chargingStateChangeReceiver)
        chargingStateChangeReceiver = null
    }

    private fun createChargingStateChangeReceiver(events: EventChannel.EventSink?): BroadcastReceiver {
        return object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1)) {
                    BatteryManager.BATTERY_STATUS_CHARGING -> events?.success("charging")
                    BatteryManager.BATTERY_STATUS_FULL -> events?.success("full")
                    BatteryManager.BATTERY_STATUS_DISCHARGING -> events?.success("discharging")
                    else -> events?.error("UNAVAILABLE", "Charging status unavailable", null)
                }
            }
        }
    }

}

```
- **Flutter**

*flutter 插件*
```
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
      
      final EventChannel eventChannel =
          const EventChannel('plugins.limit.io/charging');
      _instance = FlutterPluginLearning.init(eventChannel);
    }
    return _instance;
  }

  FlutterPluginLearning.init(this._eventChannel);

  static FlutterPluginLearning _instance;

  final EventChannel _eventChannel;
  Stream<BatteryState> _onBatteryStateChanged;

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
```
*flutter 调用*
```
FlutterPluginLearning _battery = FlutterPluginLearning();
StreamSubscription<BatteryState> _batteryStateSubscription;
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
    // do something you want
    });
```
## BasicMessageChannel

俗称消息直接通道（个人见解）用于传递字符串和半结构化的信息。
如果仅仅是简单的通信而不是调用某个方法或者是事件流, 可以使用 BasicMessageChannel。BasicMessageChannel 也可以实现 Flutter 和 Native 的双向通信, 下面的示例图就是官方的例子:

![](https://user-gold-cdn.xitu.io/2020/4/28/171bed678a87aa9a?w=400&h=831&f=png&s=80946)

详细查看[（八）Flutter 和 Native之间的通信详解](https://juejin.im/post/5d3e4e70e51d45109b01b29a#heading-5) 的 BasicMessageChannel

## Reference

[（八）Flutter 和 Native之间的通信详解](https://juejin.im/post/5d3e4e70e51d45109b01b29a#heading-5)

[官网 - platform-channels](https://flutter.dev/docs/development/platform-integration/platform-channels)

## 源码

https://github.com/TBoyLi/flutter_plugin_learning 觉得ok! Star ✨✨✨✨✨✨
