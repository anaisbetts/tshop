package dev.anais.tshop

import android.annotation.SuppressLint
import android.content.Context
import android.os.IBinder
import android.os.Parcel
import android.os.SystemClock
import android.util.Log
import java.io.File

private const val TAG = "PServiceBridge"
private const val SERVICE_NAME = "PServerBinder"
private const val TRANSACT_EXEC = 0
private const val FAIL_BACKOFF_MS = 10_000L
private const val SCRIPT_PREFIX = "tshop_pservice_"
private const val SCRIPT_SUFFIX = ".sh"
private const val OK_MARKER = "OK"
private const val ERR_PREFIX = "ERR:"

/**
 * Bridge to AYN Thor's stock `PServerBinder` root daemon (`pservice`).
 *
 * Uses raw binder transact code `0` with `[command, "0"]` and no interface token.
 * All non-trivial commands run via a temporary script in `cacheDir` (`sh <path>`)
 * because `pservice` truncates replies to one line, drops commands longer than
 * ~300 characters, and mishandles inline shell operators.
 */
object PServiceBridge {
    private val execLock = Any()
    private val probeLock = Any()

    @Volatile
    private var cachedAvailable: Boolean = false

    @Volatile
    private var lastFailElapsedMs: Long = 0L

    /**
     * Probes whether `PServerBinder` is reachable and executes as `uid=0`.
     *
     * Only positive probes are cached; failures retry after [FAIL_BACKOFF_MS]
     * so early boot races do not permanently disable root installs.
     */
    fun isAvailable(): Boolean {
        if (cachedAvailable) {
            return true
        }
        synchronized(probeLock) {
            if (cachedAvailable) {
                return true
            }
            val now = SystemClock.elapsedRealtime()
            if (lastFailElapsedMs != 0L && now - lastFailElapsedMs < FAIL_BACKOFF_MS) {
                return false
            }
            if (findBinder() == null) {
                lastFailElapsedMs = now
                return false
            }
            val reply = execRaw("id")
            if (reply != null && reply.contains("uid=0")) {
                cachedAvailable = true
                return true
            }
            lastFailElapsedMs = SystemClock.elapsedRealtime()
            return false
        }
    }

    /**
     * Writes [scriptContent] to a unique file in `context.cacheDir`, executes it
     * via `sh <path>` over `PServerBinder`, and deletes the temp script afterward.
     *
     * Calls are serialized on [execLock] because concurrent transactions drop replies.
     */
    fun runScript(context: Context, scriptContent: String): Result<String> {
        return synchronized(execLock) {
            var tempScript: File? = null
            try {
                val scriptFile = File.createTempFile(
                    SCRIPT_PREFIX,
                    SCRIPT_SUFFIX,
                    context.cacheDir,
                )
                tempScript = scriptFile
                val scriptPath = scriptFile.absolutePath
                if (scriptPath.any { it.isWhitespace() || it == '\u0000' }) {
                    return@synchronized Result.failure(
                        IllegalStateException("Unsafe cacheDir path for pservice script"),
                    )
                }
                scriptFile.writeText(scriptContent, Charsets.UTF_8)
                val reply = execRawLocked("sh $scriptPath")
                    ?: return@synchronized Result.failure(
                        IllegalStateException("PServerBinder transact failed or unavailable"),
                    )
                Result.success(reply)
            } catch (t: Throwable) {
                Log.w(TAG, "runScript failed", t)
                Result.failure(t)
            } finally {
                runCatching { tempScript?.delete() }
            }
        }
    }

    /**
     * Installs [apkFile] silently via `pm install` inside a `cacheDir` script.
     *
     * Streams the APK through stdin (`cat '<path>' | pm install -r -d -S <size>`)
     * so `pm` never needs SELinux/DAC read access into the app's private cache
     * directory, and emits a single-line `OK` or `ERR:<detail>` reply.
     */
    fun installApk(context: Context, apkFile: File): Result<Unit> {
        if (!apkFile.exists() || !apkFile.isFile) {
            return Result.failure(
                IllegalArgumentException("APK file does not exist: ${apkFile.absolutePath}"),
            )
        }
        val apkSize = apkFile.length()
        if (apkSize <= 0L) {
            return Result.failure(
                IllegalArgumentException("APK file is empty: ${apkFile.absolutePath}"),
            )
        }
        val rawPath = apkFile.absolutePath
        if (rawPath.indexOf('\u0000') >= 0) {
            return Result.failure(IllegalArgumentException("Invalid APK path"))
        }

        val quotedPath = shellSingleQuote(rawPath)
        val script = buildString {
            append("#!/system/bin/sh\n")
            append("OUT=$(cat ").append(quotedPath)
            append(" | pm install -r -d -S ").append(apkSize).append(" 2>&1)\n")
            append("RC=$?\n")
            append("case \"\$OUT\" in\n")
            append("  *Success*)\n")
            append("    if [ \"\$RC\" -eq 0 ]; then\n")
            append("      echo '").append(OK_MARKER).append("'\n")
            append("      exit 0\n")
            append("    fi\n")
            append("    ;;\n")
            append("esac\n")
            append("LAST=$(echo \"\$OUT\" | tr '\\r' '\\n' | grep -v '^[ ]*\$' | tail -n 1)\n")
            append("if [ -z \"\$LAST\" ]; then\n")
            append("  LAST=\"exit \$RC\"\n")
            append("fi\n")
            append("echo \"").append(ERR_PREFIX).append("\$LAST\"\n")
        }

        val scriptResult = runScript(context, script)
        val reply = scriptResult.getOrElse { return Result.failure(it) }
        val firstLine = reply.lineSequence().firstOrNull()?.trim().orEmpty()
        return when {
            firstLine == OK_MARKER -> Result.success(Unit)
            firstLine.startsWith(ERR_PREFIX) -> {
                val detail = firstLine.removePrefix(ERR_PREFIX).trim()
                    .ifEmpty { "pm install failed" }
                Result.failure(IllegalStateException(detail))
            }
            else -> Result.failure(
                IllegalStateException(
                    "Unexpected pservice reply: ${firstLine.ifEmpty { "<empty>" }}",
                ),
            )
        }
    }

    private fun execRaw(command: String): String? = synchronized(execLock) {
        execRawLocked(command)
    }

    private fun execRawLocked(command: String): String? {
        val binder = findBinder()
        if (binder == null) {
            cachedAvailable = false
            return null
        }
        val data = Parcel.obtain()
        val reply = Parcel.obtain()
        return try {
            data.writeStringArray(arrayOf(command, "0"))
            val transacted = binder.transact(TRANSACT_EXEC, data, reply, 0)
            if (!transacted) {
                null
            } else {
                val bytes = reply.createByteArray()
                if (bytes == null) "" else String(bytes, Charsets.UTF_8)
            }
        } catch (t: Throwable) {
            if (t is SecurityException) {
                cachedAvailable = false
            }
            Log.d(TAG, "PServerBinder transact failed: ${t.javaClass.simpleName}")
            null
        } finally {
            data.recycle()
            reply.recycle()
        }
    }

    @SuppressLint("PrivateApi")
    private fun findBinder(): IBinder? {
        return try {
            val serviceManager = Class.forName("android.os.ServiceManager")
            val getService = serviceManager.getMethod("getService", String::class.java)
            val binder = getService.invoke(null, SERVICE_NAME) as? IBinder
            if (binder != null && binder.isBinderAlive) binder else null
        } catch (_: Throwable) {
            null
        }
    }
}

private fun shellSingleQuote(value: String): String =
    "'" + value.replace("'", "'\\''") + "'"
