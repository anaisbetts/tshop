package dev.anais.tshop.composeuitests

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow

class MainActivity : ComponentActivity() {
    private val inputEvents =
        MutableSharedFlow<InputEvent>(
            extraBufferCapacity = 64,
            onBufferOverflow = BufferOverflow.DROP_OLDEST,
        )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            App(
                inputEvents = inputEvents,
                onOpenUnknownApps = ::openUnknownSources,
            )
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        inputEvents.tryEmit(describeKey(event))
        return super.dispatchKeyEvent(event)
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.isFromSource(InputDevice.SOURCE_JOYSTICK) ||
            event.isFromSource(InputDevice.SOURCE_DPAD)
        ) {
            inputEvents.tryEmit(describeMotion(event))
        }
        return super.dispatchGenericMotionEvent(event)
    }

    private fun openUnknownSources() {
        startActivity(
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                data = Uri.parse("package:$packageName")
            },
        )
    }
}
