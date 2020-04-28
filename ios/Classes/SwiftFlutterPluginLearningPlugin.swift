import Flutter
import UIKit

public class SwiftFlutterPluginLearningPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    var eventSink: FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftFlutterPluginLearningPlugin()
        let methodChannel = FlutterMethodChannel(name: "plugins.limit.io/battery", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        
        let evenChannel = FlutterEventChannel(name: "plugins.limit.io/charging", binaryMessenger: registrar.messenger())
        evenChannel.setStreamHandler(instance)
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
    
    
    private func getBatteryLevel() -> Float {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        if device.batteryState == .unknown {
            return -1;
        } else {
            return UIDevice.current.batteryLevel
        }
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
