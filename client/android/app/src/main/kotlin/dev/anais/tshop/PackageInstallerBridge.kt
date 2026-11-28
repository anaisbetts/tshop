package dev.anais.tshop

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.InputStream
import java.io.OutputStream
import java.util.concurrent.ConcurrentHashMap

private const val TAG = "PackageInstallerBridge"
private const val INSTALL_RESULT_ACTION_SUFFIX = ".INSTALL_RESULT"
private const val APK_ENTRY_NAME = "base.apk"
private const val COPY_BUFFER_SIZE = 64 * 1024

internal const val EXTRA_TSHOP_PACKAGE_NAME = "dev.anais.tshop.extra.PACKAGE_NAME"
internal const val EXTRA_TSHOP_SESSION_ID = "dev.anais.tshop.extra.SESSION_ID"

/** Stored confirmation intent awaiting user launch from the Library screen. */
internal data class PendingConfirmation(
    val sessionId: Int,
    val confirmIntent: Intent,
)

/** Listener receiving normalized install lifecycle payloads destined for Dart. */
fun interface InstallEventListener {
    fun onInstallEvent(event: Map<String, Any?>)
}

/**
 * Standard Android `PackageInstaller` session bridge with deferred confirmation.
 *
 * Confirmation dialogs emitted via `STATUS_PENDING_USER_ACTION` are stored by
 * package name rather than auto-launched, so Library can control when dialogs
 * appear without interrupting Browse.
 */
object PackageInstallerBridge {
    private val pendingConfirmations = ConcurrentHashMap<String, PendingConfirmation>()

    @Volatile
    private var eventListener: InstallEventListener? = null

    /** Registers or clears the active install event listener (typically `MainActivity`). */
    fun setEventListener(listener: InstallEventListener?) {
        eventListener = listener
    }

    /** Dispatches an install lifecycle event map to the active listener, if any. */
    fun emitEvent(event: Map<String, Any?>) {
        eventListener?.onInstallEvent(event)
    }

    /** Returns the per-applicationId broadcast action for `InstallResultReceiver`. */
    fun installResultAction(context: Context): String =
        "${context.packageName}$INSTALL_RESULT_ACTION_SUFFIX"

    /**
     * Streams [apkFile] into a new `PackageInstaller` session for [packageName]
     * and commits it, returning the created Android `sessionId`.
     */
    fun startInstall(context: Context, packageName: String, apkFile: File): Int {
        require(apkFile.exists() && apkFile.isFile) {
            "APK file does not exist: ${apkFile.absolutePath}"
        }
        val fileLength = apkFile.length()
        require(fileLength > 0L) {
            "APK file is empty: ${apkFile.absolutePath}"
        }

        cancelPendingConfirmation(context, packageName)

        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        ).apply {
            setAppPackageName(packageName)
            setSize(fileLength)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setRequireUserAction(
                    PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED,
                )
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                setPackageSource(PackageInstaller.PACKAGE_SOURCE_STORE)
            }
        }

        val sessionId = installer.createSession(params)
        var committed = false
        try {
            installer.openSession(sessionId).use { session ->
                session.openWrite(APK_ENTRY_NAME, 0L, fileLength).use { out ->
                    FileInputStream(apkFile).use { input ->
                        copyStream(input, out)
                    }
                    session.fsync(out)
                }

                val callbackIntent = Intent(context, InstallResultReceiver::class.java).apply {
                    action = installResultAction(context)
                    putExtra(EXTRA_TSHOP_PACKAGE_NAME, packageName)
                    putExtra(EXTRA_TSHOP_SESSION_ID, sessionId)
                }
                val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    sessionId,
                    callbackIntent,
                    pendingFlags,
                )
                session.commit(pendingIntent.intentSender)
                committed = true
            }
            return sessionId
        } catch (t: Throwable) {
            if (!committed) {
                runCatching { installer.abandonSession(sessionId) }
            }
            throw t
        }
    }

    /** Launches the stored system confirmation dialog for [packageName] on [activity]. */
    fun launchPendingConfirmation(activity: Activity, packageName: String): Boolean {
        val pending = pendingConfirmations[packageName] ?: return false
        return try {
            activity.startActivity(pending.confirmIntent)
            true
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to launch pending confirmation for $packageName", t)
            false
        }
    }

    /** Abandons any pending session for [packageName] and clears its stored intent. */
    fun cancelPendingConfirmation(context: Context, packageName: String) {
        val pending = pendingConfirmations.remove(packageName) ?: return
        runCatching {
            context.packageManager.packageInstaller.abandonSession(pending.sessionId)
        }
    }

    internal fun storePendingConfirmation(
        packageName: String,
        sessionId: Int,
        confirmIntent: Intent,
    ) {
        pendingConfirmations[packageName] = PendingConfirmation(
            sessionId = sessionId,
            confirmIntent = confirmIntent,
        )
    }

    internal fun clearPendingConfirmation(packageName: String) {
        pendingConfirmations.remove(packageName)
    }
}

private fun copyStream(input: InputStream, output: OutputStream) {
    val buffer = ByteArray(COPY_BUFFER_SIZE)
    while (true) {
        val read = input.read(buffer)
        if (read <= 0) {
            break
        }
        output.write(buffer, 0, read)
    }
}
