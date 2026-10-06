package dev.anais.tshop.composeuitests

import android.view.KeyEvent
import android.view.MotionEvent

const val MIN_VISIBLE_GRID_PX = 80f

sealed interface InputEvent {
    data class Key(
        val kind: String,
        val keyCode: Int,
        val keyName: String,
        val repeatCount: Int,
        val device: String,
    ) : InputEvent

    data class Motion(
        val action: String,
        val source: Int,
        val hatX: Float,
        val hatY: Float,
        val device: String,
    ) : InputEvent
}

data class RepeatWatch(
    val repeats: Int = 0,
    val intervalsMs: List<Int> = emptyList(),
    val lastAtMs: Long? = null,
) {
    fun observe(isRepeat: Boolean, nowMs: Long): RepeatWatch {
        if (!isRepeat) {
            return RepeatWatch(lastAtMs = nowMs)
        }
        val interval = if (lastAtMs == null) 0 else (nowMs - lastAtMs).toInt()
        return RepeatWatch(
            repeats = repeats + 1,
            intervalsMs = intervalsMs + listOfNotNull(interval.takeIf { it > 0 }),
            lastAtMs = nowMs,
        )
    }

    fun summary(): String {
        if (repeats == 0) {
            return "none"
        }
        if (intervalsMs.isEmpty()) {
            return "$repeats (cadence unknown)"
        }
        return "$repeats, last ${intervalsMs.last()}ms"
    }
}

fun keyKind(action: Int): String {
    return when (action) {
        KeyEvent.ACTION_DOWN -> "down"
        KeyEvent.ACTION_UP -> "up"
        else -> "action $action"
    }
}

fun isDpad(keyCode: Int): Boolean {
    return keyCode == KeyEvent.KEYCODE_DPAD_UP ||
        keyCode == KeyEvent.KEYCODE_DPAD_DOWN ||
        keyCode == KeyEvent.KEYCODE_DPAD_LEFT ||
        keyCode == KeyEvent.KEYCODE_DPAD_RIGHT
}

fun isFaceA(keyCode: Int): Boolean {
    return keyCode == KeyEvent.KEYCODE_BUTTON_A || keyCode == KeyEvent.KEYCODE_DPAD_CENTER
}

fun formatMotion(event: InputEvent.Motion): String {
    return "hatX ${"%.2f".format(event.hatX)}  hatY ${"%.2f".format(event.hatY)}"
}

fun gridRemainsVisible(remainingHeight: Float, minVisible: Float = MIN_VISIBLE_GRID_PX): Boolean {
    return remainingHeight >= minVisible
}

fun describeKey(event: KeyEvent): InputEvent.Key {
    val kind = if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount > 0) {
        "repeat"
    } else {
        keyKind(event.action)
    }
    return InputEvent.Key(
        kind = kind,
        keyCode = event.keyCode,
        keyName = KeyEvent.keyCodeToString(event.keyCode),
        repeatCount = event.repeatCount,
        device = event.device?.name ?: "",
    )
}

fun describeMotion(event: MotionEvent): InputEvent.Motion {
    return InputEvent.Motion(
        action = MotionEvent.actionToString(event.action),
        source = event.source,
        hatX = event.getAxisValue(MotionEvent.AXIS_HAT_X),
        hatY = event.getAxisValue(MotionEvent.AXIS_HAT_Y),
        device = event.device?.name ?: "",
    )
}
