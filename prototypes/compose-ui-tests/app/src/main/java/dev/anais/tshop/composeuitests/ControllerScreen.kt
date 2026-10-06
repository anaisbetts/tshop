package dev.anais.tshop.composeuitests

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.flow.Flow

private const val MAX_LOG = 80

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ControllerScreen(
    events: Flow<InputEvent>,
    onBack: () -> Unit,
    onOpenUnknownApps: () -> Unit = {},
) {
    val log = remember { mutableStateListOf<String>() }
    var dpad by remember { mutableStateOf(RepeatWatch()) }
    var faceA by remember { mutableStateOf(RepeatWatch()) }
    var hat by remember { mutableStateOf("none") }

    LaunchedEffect(events) {
        events.collect { event ->
            val now = System.currentTimeMillis()
            when (event) {
                is InputEvent.Key -> {
                    val line = "${event.kind}  ${event.keyName}  repeat=${event.repeatCount}  ${event.device}"
                    log.add(0, line)
                    if (isDpad(event.keyCode)) {
                        dpad = dpad.observe(event.kind == "repeat", now)
                    }
                    if (isFaceA(event.keyCode)) {
                        faceA = faceA.observe(event.kind == "repeat", now)
                    }
                }
                is InputEvent.Motion -> {
                    hat = formatMotion(event)
                    log.add(0, "motion  ${event.device} src=${event.source}  $hat")
                }
            }
            if (log.size > MAX_LOG) {
                log.removeAt(log.lastIndex)
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("#2 Controller input") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            Surface(color = MaterialTheme.colorScheme.surfaceContainerHigh) {
                Column(Modifier.padding(12.dp)) {
                    Text(
                        "Press every control. Hold d-pad, then hold A.",
                        style = MaterialTheme.typography.titleMedium,
                    )
                    Text("D-pad repeats: ${dpad.summary()}")
                    Text("A repeats: ${faceA.summary()}")
                    Text("Last hat: $hat")
                    Text("If motion stays \"none\" and no DPAD keys appear, Compose never saw the pad.")
                }
            }
            FilledTonalButton(
                onClick = onOpenUnknownApps,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(16.dp, 8.dp),
            ) {
                Text("Open unknown-apps Settings")
            }
            LazyColumn(
                modifier =
                    Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp),
            ) {
                items(log) { line ->
                    Text(line, style = MaterialTheme.typography.bodyMedium, fontFamily = FontFamily.Monospace)
                }
            }
        }
    }
}
