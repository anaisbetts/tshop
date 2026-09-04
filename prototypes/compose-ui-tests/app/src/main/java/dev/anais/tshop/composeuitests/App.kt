package dev.anais.tshop.composeuitests

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow

sealed interface Screen {
    data object Home : Screen

    data object Controller : Screen

    data object FocusKitchen : Screen

    data object Ime : Screen
}

@Composable
fun App(inputEvents: Flow<InputEvent> = emptyFlow()) {
    var screen by remember { mutableStateOf<Screen>(Screen.Home) }
    MaterialTheme(colorScheme = protoColors()) {
        when (screen) {
            Screen.Home ->
                HomeScreen(onOpen = { screen = it })
            Screen.Controller ->
                ControllerScreen(
                    events = inputEvents,
                    onBack = { screen = Screen.Home },
                )
            Screen.FocusKitchen ->
                FocusKitchenScreen(onBack = { screen = Screen.Home })
            Screen.Ime ->
                ImeScreen(onBack = { screen = Screen.Home })
        }
    }
}

private fun protoColors() = darkColorScheme(primary = Color(0xFF8EB4FF))
