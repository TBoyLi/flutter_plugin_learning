package com.redli.flutter_plugin_learning

import android.content.*
import android.os.BatteryManager
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat.getSystemService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar


/** FlutterPluginLearningPlugin */
public class FlutterPluginLearningPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private var applicationContext: Context? = null

    /**
     * 方法通道
     */
    private var methodChannel: MethodChannel? = null

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
        methodChannel = MethodChannel(messenger, "plugins.limit.io/battery")
        eventChannel = EventChannel(messenger, "plugins.limit.io/charging")
        methodChannel?.setMethodCallHandler(this)
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
