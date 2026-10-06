package dev.anais.tshop.composeuitests

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.unit.dp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.TextButton
import androidx.tv.material3.Button
import androidx.tv.material3.Card
import androidx.tv.material3.Icon
import androidx.tv.material3.IconButton
import androidx.tv.material3.ListItem
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.OutlinedButton
import androidx.tv.material3.Surface
import androidx.tv.material3.Switch
import androidx.tv.material3.Text
import androidx.tv.material3.darkColorScheme

@Composable
fun FocusTvKitchenScreen(onBack: () -> Unit) {
    var focus by remember { mutableStateOf("none") }
    var search by remember { mutableStateOf("") }
    var wifi by remember { mutableStateOf(true) }
    var agree by remember { mutableStateOf(false) }
    var radio by remember { mutableStateOf("a") }
    var volume by remember { mutableFloatStateOf(0.4f) }
    val chips = remember { mutableStateOf(setOf("ARM", "x64")) }
    var expanded by remember { mutableStateOf(false) }
    var dialog by remember { mutableStateOf(false) }

    fun track(label: String): Modifier = Modifier.onFocusChanged { if (it.isFocused) focus = label }

    MaterialTheme(colorScheme = darkColorScheme()) {
        Surface(modifier = Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier.padding(16.dp, 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    IconButton(onClick = onBack, modifier = track("Back")) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                    Column {
                        Text("Focus kitchen — Compose TV", style = MaterialTheme.typography.titleLarge)
                        Text("Focus: $focus", style = MaterialTheme.typography.bodyMedium)
                    }
                }
                Text(
                    "androidx.tv.material3 widgets. Phone TextField/Slider/Dialog stay Material3 — TV has none.",
                    modifier = Modifier.padding(horizontal = 16.dp),
                    style = MaterialTheme.typography.bodySmall,
                )
                LazyColumn(
                    modifier = Modifier.fillMaxSize().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    item { TvSection("Row of buttons") }
                    item {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(onClick = {}, modifier = track("Install")) { Text("Install") }
                            Button(onClick = {}, modifier = track("Update")) { Text("Update") }
                            OutlinedButton(onClick = {}, modifier = track("Open")) { Text("Open") }
                            IconButton(onClick = {}, modifier = track("More")) {
                                Icon(Icons.Default.MoreVert, contentDescription = "More")
                            }
                        }
                    }
                    item { TvSection("Phone TextField — TV has no IME field") }
                    item {
                        OutlinedTextField(
                            value = search,
                            onValueChange = { search = it },
                            modifier = Modifier.fillMaxWidth().then(track("Search")),
                            label = { androidx.compose.material3.Text("Search") },
                            singleLine = true,
                        )
                    }
                    item { TvSection("Toggles") }
                    item {
                        ListItem(
                            selected = wifi,
                            onClick = { wifi = !wifi },
                            modifier = track("Wi-Fi"),
                            headlineContent = { Text("Wi-Fi") },
                            trailingContent = { Switch(checked = wifi, onCheckedChange = { wifi = it }) },
                        )
                    }
                    item {
                        ListItem(
                            selected = agree,
                            onClick = { agree = !agree },
                            modifier = track("I agree"),
                            headlineContent = { Text("I agree") },
                        )
                    }
                    item {
                        ListItem(
                            selected = radio == "a",
                            onClick = { radio = "a" },
                            modifier = track("ARM64"),
                            headlineContent = { Text("ARM64") },
                        )
                    }
                    item {
                        ListItem(
                            selected = radio == "b",
                            onClick = { radio = "b" },
                            modifier = track("ARM32"),
                            headlineContent = { Text("ARM32") },
                        )
                    }
                    item { TvSection("Phone Slider — TV has none") }
                    item {
                        Slider(
                            value = volume,
                            onValueChange = { volume = it },
                            modifier = track("Slider"),
                        )
                    }
                    item { TvSection("Chips as selected ListItems") }
                    item {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            for (chip in listOf("ARM", "x64", "Vulkan")) {
                                val on = chip in chips.value
                                Button(
                                    onClick = {
                                        chips.value =
                                            if (on) chips.value - chip else chips.value + chip
                                    },
                                    modifier = track("Chip $chip"),
                                ) {
                                    Text(if (on) "✓ $chip" else chip)
                                }
                            }
                        }
                    }
                    item { TvSection("List items") }
                    item {
                        ListItem(
                            selected = false,
                            onClick = {},
                            modifier = track("PPSSPP tile"),
                            headlineContent = { Text("PPSSPP") },
                            supportingContent = { Text("PlayStation Portable") },
                            leadingContent = {
                                Icon(Icons.Default.SportsEsports, contentDescription = null)
                            },
                        )
                    }
                    item {
                        ListItem(
                            selected = false,
                            onClick = {},
                            modifier = track("Settings row"),
                            headlineContent = { Text("Settings row") },
                            leadingContent = {
                                Icon(Icons.Default.Settings, contentDescription = null)
                            },
                        )
                    }
                    item { TvSection("2×3 grid of TV Cards") }
                    item {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            listOf(
                                listOf("PPSSPP", "RetroArch"),
                                listOf("Dolphin", "Flycast"),
                                listOf("Azahar", "ScummVM"),
                            ).forEach { row ->
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    modifier = Modifier.fillMaxWidth(),
                                ) {
                                    row.forEach { name ->
                                        Card(
                                            onClick = {},
                                            modifier =
                                                Modifier
                                                    .weight(1f)
                                                    .height(72.dp)
                                                    .then(track("Grid $name")),
                                        ) {
                                            Text(name, modifier = Modifier.padding(16.dp))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    item {
                        ListItem(
                            selected = expanded,
                            onClick = { expanded = !expanded },
                            modifier = track("Expansion"),
                            headlineContent = { Text("Expansion — can you enter and leave?") },
                        )
                    }
                    if (expanded) {
                        item {
                            ListItem(
                                selected = false,
                                onClick = {},
                                modifier = track("Inside A"),
                                headlineContent = { Text("Inside A") },
                            )
                        }
                        item {
                            ListItem(
                                selected = false,
                                onClick = {},
                                modifier = track("Inside B"),
                                headlineContent = { Text("Inside B") },
                            )
                        }
                    }
                    item { TvSection("Overlay — phone AlertDialog") }
                    item {
                        Button(onClick = { dialog = true }, modifier = track("Open dialog")) {
                            Text("Open dialog")
                        }
                    }
                }
            }
        }
    }

    if (dialog) {
        AlertDialog(
            onDismissRequest = { dialog = false },
            title = { androidx.compose.material3.Text("Modal") },
            text = {
                androidx.compose.material3.Text(
                    "TV Material has no dialog. This is phone AlertDialog. " +
                        "Can the d-pad reach the actions? Does focus return?",
                )
            },
            confirmButton = {
                TextButton(onClick = { dialog = false }) {
                    androidx.compose.material3.Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = { dialog = false }) {
                    androidx.compose.material3.Text("Cancel")
                }
            },
        )
    }
}

@Composable
private fun TvSection(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.titleSmall,
        modifier = Modifier.padding(top = 12.dp, bottom = 4.dp),
    )
}
