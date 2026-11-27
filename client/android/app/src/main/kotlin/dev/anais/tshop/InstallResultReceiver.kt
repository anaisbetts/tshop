package dev.anais.tshop

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build

private const val UNKNOWN_SESSION_ID = -1

/**
 * Receives `PackageInstaller` session commit results and forwards normalized
 * lifecycle events to [PackageInstallerBridge].
 *
 * On `STATUS_PENDING_USER_ACTION`, stores the confirmation `Intent` without
 * launching it automatically so browsing is never interrupted.
 */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE,
        )
        val sessionId = intent.getIntExtra(
            PackageInstaller.EXTRA_SESSION_ID,
            intent.getIntExtra(EXTRA_TSHOP_SESSION_ID, UNKNOWN_SESSION_ID),
        )
        val packageName = intent.getStringExtra(PackageInstaller.EXTRA_PACKAGE_NAME)
            ?.takeIf { it.isNotEmpty() }
            ?: intent.getStringExtra(EXTRA_TSHOP_PACKAGE_NAME).orEmpty()
        val statusMessage = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)

        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirmIntent = extractConfirmIntent(intent)
                if (confirmIntent != null && packageName.isNotEmpty()) {
                    PackageInstallerBridge.storePendingConfirmation(
                        packageName = packageName,
                        sessionId = sessionId,
                        confirmIntent = confirmIntent,
                    )
                    PackageInstallerBridge.emitEvent(
                        mapOf(
                            "type" to "awaiting_confirmation",
                            "packageName" to packageName,
                            "sessionId" to sessionId,
                        ),
                    )
                } else {
                    PackageInstallerBridge.emitEvent(
                        mapOf(
                            "type" to "failed",
                            "packageName" to packageName,
                            "sessionId" to sessionId,
                            "message" to "Missing PackageInstaller confirmation intent",
                            "aborted" to false,
                        ),
                    )
                }
            }

            PackageInstaller.STATUS_SUCCESS -> {
                if (packageName.isNotEmpty()) {
                    PackageInstallerBridge.clearPendingConfirmation(packageName)
                }
                PackageInstallerBridge.emitEvent(
                    mapOf(
                        "type" to "succeeded",
                        "packageName" to packageName,
                        "sessionId" to sessionId,
                    ),
                )
            }

            PackageInstaller.STATUS_FAILURE_ABORTED -> {
                if (packageName.isNotEmpty()) {
                    PackageInstallerBridge.clearPendingConfirmation(packageName)
                }
                PackageInstallerBridge.emitEvent(
                    mapOf(
                        "type" to "failed",
                        "packageName" to packageName,
                        "sessionId" to sessionId,
                        "message" to (statusMessage?.takeIf { it.isNotBlank() }
                            ?: "Install aborted by user"),
                        "aborted" to true,
                    ),
                )
            }

            else -> {
                if (packageName.isNotEmpty()) {
                    PackageInstallerBridge.clearPendingConfirmation(packageName)
                }
                PackageInstallerBridge.emitEvent(
                    mapOf(
                        "type" to "failed",
                        "packageName" to packageName,
                        "sessionId" to sessionId,
                        "message" to (statusMessage?.takeIf { it.isNotBlank() }
                            ?: fallbackFailureMessage(status)),
                        "aborted" to false,
                    ),
                )
            }
        }
    }
}

private fun extractConfirmIntent(intent: Intent): Intent? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
    } else {
        @Suppress("DEPRECATION")
        intent.getParcelableExtra(Intent.EXTRA_INTENT)
    }
}

private fun fallbackFailureMessage(status: Int): String = when (status) {
    PackageInstaller.STATUS_FAILURE_BLOCKED -> "Install blocked by system policy"
    PackageInstaller.STATUS_FAILURE_CONFLICT -> "Package conflicts with an existing install"
    PackageInstaller.STATUS_FAILURE_INCOMPATIBLE -> "Package is incompatible with this device"
    PackageInstaller.STATUS_FAILURE_INVALID -> "APK package is invalid or corrupt"
    PackageInstaller.STATUS_FAILURE_STORAGE -> "Insufficient storage space"
    PackageInstaller.STATUS_FAILURE_TIMEOUT -> "Install timed out"
    else -> "PackageInstaller failed (status $status)"
}
