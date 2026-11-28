package dev.anais.tshop

import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.InputDevice
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

private const val TAG = "MainActivity"
private const val APP_SERVICES_CHANNEL = "dev.anais.tshop/app_services"
private const val INSTALL_EVENTS_CHANNEL = "dev.anais.tshop/install_events"
private const val GAMEPAD_HAT_CHANNEL = "dev.anais.tshop/gamepad_hat"
private const val HAT_AXIS_THRESHOLD = 0.5f
private const val IO_THREAD_COUNT = 2

/**
 * Flutter host activity wiring Android package services, install lifecycle events,
 * and gamepad `AXIS_HAT_X/Y` d-pad input into Dart.
 */
class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor: ExecutorService = Executors.newFixedThreadPool(IO_THREAD_COUNT)

    @Volatile
    private var installEventSink: EventChannel.EventSink? = null

    @Volatile
    private var gamepadHatSink: EventChannel.EventSink? = null

    private var lastHatX: Int = 0
    private var lastHatY: Int = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, APP_SERVICES_CHANNEL)
            .setMethodCallHandler(::handleMethodCall)

        EventChannel(messenger, INSTALL_EVENTS_CHANNEL)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                        installEventSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        installEventSink = null
                    }
                },
            )

        EventChannel(messenger, GAMEPAD_HAT_CHANNEL)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                        lastHatX = 0
                        lastHatY = 0
                        gamepadHatSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        gamepadHatSink = null
                    }
                },
            )

        PackageInstallerBridge.setEventListener(::emitInstallEvent)
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (isGamepadMotionSource(event)) {
            val hatX = quantizeHatAxis(event.getAxisValue(MotionEvent.AXIS_HAT_X))
            val hatY = quantizeHatAxis(event.getAxisValue(MotionEvent.AXIS_HAT_Y))
            if (hatX != lastHatX || hatY != lastHatY) {
                lastHatX = hatX
                lastHatY = hatY
                emitGamepadHatEvent(hatX, hatY)
            }
        }
        return super.dispatchGenericMotionEvent(event)
    }

    override fun onDestroy() {
        PackageInstallerBridge.setEventListener(null)
        installEventSink = null
        gamepadHatSink = null
        ioExecutor.shutdown()
        super.onDestroy()
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "deviceInfo" -> handleDeviceInfo(result)
            "scanInstalled" -> handleScanInstalled(result)
            "canRequestPackageInstalls" -> {
                result.success(PackageScanner.canRequestPackageInstalls(applicationContext))
            }
            "openInstallPermissionSettings" -> handleOpenInstallPermissionSettings(result)
            "installApkFile" -> handleInstallApkFile(call, result)
            "launchPendingConfirmation" -> handleLaunchPendingConfirmation(call, result)
            "cancelPendingConfirmation" -> handleCancelPendingConfirmation(call, result)
            "openInstalled" -> handleOpenInstalled(call, result)
            "uninstallPackage" -> handleUninstallPackage(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleDeviceInfo(result: MethodChannel.Result) {
        ioExecutor.execute {
            try {
                val hasPService = PServiceBridge.isAvailable()
                val info = PackageScanner.deviceInfo(applicationContext, hasPService)
                postSuccess(result, info)
            } catch (t: Throwable) {
                postError(result, "DEVICE_INFO_FAILED", t.message ?: "Failed to read device info")
            }
        }
    }

    private fun handleScanInstalled(result: MethodChannel.Result) {
        ioExecutor.execute {
            try {
                val packages = PackageScanner.scanInstalled(applicationContext)
                postSuccess(result, packages)
            } catch (t: Throwable) {
                postError(result, "SCAN_FAILED", t.message ?: "Failed to scan installed packages")
            }
        }
    }

    private fun handleOpenInstallPermissionSettings(result: MethodChannel.Result) {
        try {
            PackageScanner.openInstallPermissionSettings(this)
            result.success(null)
        } catch (t: Throwable) {
            result.error(
                "OPEN_SETTINGS_FAILED",
                t.message ?: "Could not open install unknown apps settings",
                null,
            )
        }
    }

    private fun handleInstallApkFile(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName")?.trim().orEmpty()
        val filePath = call.argument<String>("filePath")?.trim().orEmpty()
        if (packageName.isEmpty() || filePath.isEmpty()) {
            result.error(
                "INVALID_ARGS",
                "installApkFile requires non-empty packageName and filePath",
                null,
            )
            return
        }

        ioExecutor.execute {
            val apkFile = File(filePath)
            if (!apkFile.exists() || !apkFile.isFile) {
                postError(result, "FILE_NOT_FOUND", "APK file not found: $filePath")
                return@execute
            }

            if (PServiceBridge.isAvailable()) {
                val pserviceResult = PServiceBridge.installApk(applicationContext, apkFile)
                if (pserviceResult.isSuccess) {
                    emitInstallEvent(
                        mapOf(
                            "type" to "succeeded",
                            "packageName" to packageName,
                            "sessionId" to 0,
                        ),
                    )
                    postSuccess(result, null)
                    return@execute
                }
                Log.w(
                    TAG,
                    "PServiceBridge install failed for $packageName; falling back to PackageInstaller",
                    pserviceResult.exceptionOrNull(),
                )
            }

            try {
                PackageInstallerBridge.startInstall(applicationContext, packageName, apkFile)
                postSuccess(result, null)
            } catch (t: Throwable) {
                postError(
                    result,
                    "INSTALL_FAILED",
                    t.message ?: "Failed to start PackageInstaller session",
                )
            }
        }
    }

    private fun handleLaunchPendingConfirmation(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName")?.trim().orEmpty()
        if (packageName.isEmpty()) {
            result.error("INVALID_ARGS", "launchPendingConfirmation requires packageName", null)
            return
        }
        result.success(PackageInstallerBridge.launchPendingConfirmation(this, packageName))
    }

    private fun handleCancelPendingConfirmation(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName")?.trim().orEmpty()
        if (packageName.isEmpty()) {
            result.error("INVALID_ARGS", "cancelPendingConfirmation requires packageName", null)
            return
        }
        PackageInstallerBridge.cancelPendingConfirmation(applicationContext, packageName)
        result.success(null)
    }

    private fun handleOpenInstalled(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName")?.trim().orEmpty()
        if (packageName.isEmpty()) {
            result.error("INVALID_ARGS", "openInstalled requires packageName", null)
            return
        }
        try {
            result.success(PackageScanner.openInstalled(this, packageName))
        } catch (t: Throwable) {
            result.error("OPEN_FAILED", t.message ?: "Failed to open $packageName", null)
        }
    }

    private fun handleUninstallPackage(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName")?.trim().orEmpty()
        if (packageName.isEmpty()) {
            result.error("INVALID_ARGS", "uninstallPackage requires packageName", null)
            return
        }
        try {
            PackageScanner.requestUninstall(this, packageName)
            result.success(null)
        } catch (t: Throwable) {
            result.error("UNINSTALL_FAILED", t.message ?: "Failed to uninstall $packageName", null)
        }
    }

    private fun emitInstallEvent(event: Map<String, Any?>) {
        mainHandler.post {
            installEventSink?.success(event)
        }
    }

    private fun emitGamepadHatEvent(x: Int, y: Int) {
        val payload = mapOf("x" to x, "y" to y)
        if (Looper.myLooper() == Looper.getMainLooper()) {
            gamepadHatSink?.success(payload)
        } else {
            mainHandler.post {
                gamepadHatSink?.success(payload)
            }
        }
    }

    private fun postSuccess(result: MethodChannel.Result, value: Any?) {
        mainHandler.post {
            result.success(value)
        }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post {
            result.error(code, message, null)
        }
    }
}

private fun isGamepadMotionSource(event: MotionEvent): Boolean =
    event.isFromSource(InputDevice.SOURCE_JOYSTICK) ||
        event.isFromSource(InputDevice.SOURCE_DPAD)

private fun quantizeHatAxis(value: Float): Int = when {
    value <= -HAT_AXIS_THRESHOLD -> -1
    value >= HAT_AXIS_THRESHOLD -> 1
    else -> 0
}
