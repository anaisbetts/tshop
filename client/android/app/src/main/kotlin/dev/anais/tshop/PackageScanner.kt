package dev.anais.tshop

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import java.security.MessageDigest

private const val TAG = "PackageScanner"
private const val DIGEST_ALGORITHM = "SHA-256"
private const val HEX_CHARS = "0123456789abcdef"

/**
 * Inspects installed packages, signing certificates, device capabilities,
 * and standard Android package actions (open, uninstall, install settings).
 */
object PackageScanner {
    /**
     * Scans installed packages with narrow signing-certificate flags and returns
     * channel-ready maps containing `packageName`, `versionCode`, `signingSha256`,
     * and `signingSha256s`.
     */
    fun scanInstalled(context: Context): List<Map<String, Any>> {
        val pm = context.packageManager
        val digest = MessageDigest.getInstance(DIGEST_ALGORITHM)
        val packages = loadInstalledPackages(pm)
        return packages.map { info ->
            val sha256List = extractSigningSha256s(info, digest)
            mapOf(
                "packageName" to info.packageName,
                "versionCode" to extractVersionCode(info),
                "signingSha256" to (sha256List.firstOrNull() ?: ""),
                "signingSha256s" to sha256List,
            )
        }
    }

    /** Reports device ABIs, Android SDK level, and `PServiceBridge` availability. */
    fun deviceInfo(context: Context, hasPService: Boolean): Map<String, Any> {
        // context reserved for future hardware capability queries.
        context.applicationContext
        return mapOf(
            "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
            "sdkInt" to Build.VERSION.SDK_INT,
            "hasPServiceBridge" to hasPService,
        )
    }

    /** Whether the user has granted "Install unknown apps" for this app. */
    fun canRequestPackageInstalls(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    /** Opens the per-app "Install unknown apps" Android Settings screen. */
    fun openInstallPermissionSettings(activity: Activity) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                data = Uri.parse("package:${activity.packageName}")
            }
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }
        activity.startActivity(intent)
    }

    /** Launches [packageName]'s main activity, returning `false` if none exists. */
    fun openInstalled(activity: Activity, packageName: String): Boolean {
        val launchIntent = activity.packageManager.getLaunchIntentForPackage(packageName)
            ?: return false
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(launchIntent)
        return true
    }

    /** Opens Android's standard uninstall confirmation dialog for [packageName]. */
    fun requestUninstall(activity: Activity, packageName: String) {
        val intent = Intent(Intent.ACTION_DELETE, Uri.parse("package:$packageName"))
        activity.startActivity(intent)
    }
}

private fun loadInstalledPackages(pm: PackageManager): List<PackageInfo> {
    return try {
        queryAllWithSigningCerts(pm)
    } catch (t: RuntimeException) {
        Log.w(TAG, "Bulk getInstalledPackages failed; falling back per-package", t)
        loadPerPackageFallback(pm)
    }
}

private fun queryAllWithSigningCerts(pm: PackageManager): List<PackageInfo> {
    return when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> {
            pm.getInstalledPackages(
                PackageManager.PackageInfoFlags.of(
                    PackageManager.GET_SIGNING_CERTIFICATES.toLong(),
                ),
            )
        }
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.P -> {
            @Suppress("DEPRECATION")
            pm.getInstalledPackages(PackageManager.GET_SIGNING_CERTIFICATES)
        }
        else -> {
            @Suppress("DEPRECATION")
            pm.getInstalledPackages(PackageManager.GET_SIGNATURES)
        }
    }
}

private fun loadPerPackageFallback(pm: PackageManager): List<PackageInfo> {
    val apps = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0L))
    } else {
        @Suppress("DEPRECATION")
        pm.getInstalledApplications(0)
    }
    val results = ArrayList<PackageInfo>(apps.size)
    for (app in apps) {
        val info = runCatching {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> {
                    pm.getPackageInfo(
                        app.packageName,
                        PackageManager.PackageInfoFlags.of(
                            PackageManager.GET_SIGNING_CERTIFICATES.toLong(),
                        ),
                    )
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.P -> {
                    @Suppress("DEPRECATION")
                    pm.getPackageInfo(app.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                }
                else -> {
                    @Suppress("DEPRECATION")
                    pm.getPackageInfo(app.packageName, PackageManager.GET_SIGNATURES)
                }
            }
        }.getOrNull()
        if (info != null) {
            results.add(info)
        }
    }
    return results
}

private fun extractVersionCode(info: PackageInfo): Long {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        info.longVersionCode
    } else {
        @Suppress("DEPRECATION")
        info.versionCode.toLong()
    }
}

private fun extractSigningSha256s(
    info: PackageInfo,
    digest: MessageDigest,
): List<String> {
    val signatures = LinkedHashSet<String>()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        val signingInfo = info.signingInfo
        if (signingInfo != null) {
            addSignatureDigests(signingInfo.apkContentsSigners, digest, signatures)
            if (signingInfo.hasPastSigningCertificates()) {
                addSignatureDigests(signingInfo.signingCertificateHistory, digest, signatures)
            }
        }
    } else {
        @Suppress("DEPRECATION")
        addSignatureDigests(info.signatures, digest, signatures)
    }
    return signatures.toList()
}

private fun addSignatureDigests(
    rawSignatures: Array<Signature>?,
    digest: MessageDigest,
    target: MutableSet<String>,
) {
    if (rawSignatures == null) {
        return
    }
    for (signature in rawSignatures) {
        digest.reset()
        val hash = digest.digest(signature.toByteArray())
        target.add(toLowerHex(hash))
    }
}

private fun toLowerHex(bytes: ByteArray): String {
    val out = CharArray(bytes.size * 2)
    for (i in bytes.indices) {
        val value = bytes[i].toInt() and 0xFF
        out[i * 2] = HEX_CHARS[value ushr 4]
        out[i * 2 + 1] = HEX_CHARS[value and 0x0F]
    }
    return String(out)
}
