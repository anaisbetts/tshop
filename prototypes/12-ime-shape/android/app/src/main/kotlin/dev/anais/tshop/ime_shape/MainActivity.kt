package dev.anais.tshop.ime_shape

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.view.InputDevice
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var motionSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MOTION_CHANNEL)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                        motionSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        motionSink = null
                    }
                },
            )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openUnknownSources") {
                    startActivity(
                        Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            data = Uri.parse("package:$packageName")
                        },
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.isFromSource(InputDevice.SOURCE_JOYSTICK) ||
            event.isFromSource(InputDevice.SOURCE_DPAD)
        ) {
            motionSink?.success(
                mapOf(
                    "action" to MotionEvent.actionToString(event.action),
                    "source" to event.source,
                    "hatX" to event.getAxisValue(MotionEvent.AXIS_HAT_X),
                    "hatY" to event.getAxisValue(MotionEvent.AXIS_HAT_Y),
                    "device" to (event.device?.name ?: ""),
                ),
            )
        }
        return super.dispatchGenericMotionEvent(event)
    }

    companion object {
        private const val MOTION_CHANNEL = "dev.anais.tshop.ime_shape/motion"
        private const val SETTINGS_CHANNEL = "dev.anais.tshop.ime_shape/settings"
    }
}
