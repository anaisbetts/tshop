package dev.anais.tshop.composeuitests

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuAnchorType
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun FocusKitchenScreen(onBack: () -> Unit) {
    var focus by remember { mutableStateOf("none") }
    var search by remember { mutableStateOf("") }
    var wifi by remember { mutableStateOf(true) }
    var agree by remember { mutableStateOf(false) }
    var radio by remember { mutableStateOf("a") }
    var volume by remember { mutableFloatStateOf(0.4f) }
    var core by remember { mutableStateOf("PPSSPP") }
    var coreOpen by remember { mutableStateOf(false) }
    var menuOpen by remember { mutableStateOf(false) }
    val chips = remember { mutableStateOf(setOf("ARM", "x64")) }
    var expanded by remember { mutableStateOf(false) }
    var dialog by remember { mutableStateOf(false) }

    fun track(label: String): Modifier = Modifier.onFocusChanged { if (it.isFocused) focus = label }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Focus kitchen") },
                navigationIcon = {
                    IconButton(onClick = onBack, modifier = track("Back")) {
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
                    Text("Focus: $focus", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "Walk every control with the d-pad. Stock Material3 — no Compose TV, no remaps.",
                    )
                }
            }
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp, 8.dp, 16.dp, 24.dp),
            ) {
                Section("Row of buttons — does Left/Right follow geometry?")
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = {}, modifier = track("Install")) { Text("Install") }
                    FilledTonalButton(onClick = {}, modifier = track("Update")) { Text("Update") }
                    OutlinedButton(onClick = {}, modifier = track("Open")) { Text("Open") }
                    IconButton(onClick = {}, modifier = track("More")) {
                        Icon(Icons.Default.MoreVert, contentDescription = "More")
                    }
                }
                Section("Text field — arrows may move the caret, not focus")
                OutlinedTextField(
                    value = search,
                    onValueChange = { search = it },
                    modifier = Modifier.fillMaxWidth().then(track("Search")),
                    label = { Text("Search") },
                    singleLine = true,
                )
                Section("Toggles")
                Row(verticalAlignment = Alignment.CenterVertically, modifier = track("Wi-Fi").fillMaxWidth()) {
                    Text("Wi-Fi", Modifier.weight(1f))
                    Switch(checked = wifi, onCheckedChange = { wifi = it })
                }
                Row(verticalAlignment = Alignment.CenterVertically, modifier = track("I agree").fillMaxWidth()) {
                    Text("I agree", Modifier.weight(1f))
                    Checkbox(checked = agree, onCheckedChange = { agree = it })
                }
                RadioRow("ARM64", "a", radio, { radio = it }, track("ARM64"))
                RadioRow("ARM32", "b", radio, { radio = it }, track("ARM32"))
                Section("Slider — Left/Right usually change the value")
                Slider(
                    value = volume,
                    onValueChange = { volume = it },
                    modifier = track("Slider"),
                )
                Section("Menus")
                ExposedDropdownMenuBox(expanded = coreOpen, onExpandedChange = { coreOpen = it }) {
                    OutlinedTextField(
                        value = core,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Core") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(coreOpen) },
                        modifier =
                            Modifier
                                .menuAnchor(
                                    type = ExposedDropdownMenuAnchorType.PrimaryNotEditable,
                                    enabled = true,
                                )
                                .fillMaxWidth()
                                .then(track("Dropdown")),
                    )
                    ExposedDropdownMenu(expanded = coreOpen, onDismissRequest = { coreOpen = false }) {
                        listOf("PPSSPP", "RetroArch", "Dolphin").forEach { item ->
                            DropdownMenuItem(
                                text = { Text(item) },
                                onClick = {
                                    core = item
                                    coreOpen = false
                                },
                            )
                        }
                    }
                }
                ListItem(
                    headlineContent = { Text("Overflow menu") },
                    trailingContent = {
                        IconButton(onClick = { menuOpen = true }, modifier = track("Overflow")) {
                            Icon(Icons.Default.MoreVert, contentDescription = "Overflow")
                        }
                        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                            DropdownMenuItem(text = { Text("Details") }, onClick = { menuOpen = false })
                            DropdownMenuItem(text = { Text("Uninstall") }, onClick = { menuOpen = false })
                        }
                    },
                )
                Section("Chips")
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (chip in listOf("ARM", "x64", "Vulkan")) {
                        FilterChip(
                            selected = chip in chips.value,
                            onClick = {
                                chips.value = if (chip in chips.value) chips.value - chip else chips.value + chip
                            },
                            label = { Text(chip) },
                            modifier = track("Chip $chip"),
                        )
                    }
                }
                Section("List tiles")
                ListItem(
                    leadingContent = { Icon(Icons.Default.SportsEsports, contentDescription = null) },
                    headlineContent = { Text("PPSSPP") },
                    supportingContent = { Text("PlayStation Portable") },
                    modifier = track("PPSSPP tile"),
                )
                ListItem(
                    leadingContent = { Icon(Icons.Default.Settings, contentDescription = null) },
                    headlineContent = { Text("Settings row") },
                    modifier = track("Settings row").clickable { },
                )
                Section("2×3 grid — Down should not become Next-in-document")
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(
                        listOf("PPSSPP", "RetroArch"),
                        listOf("Dolphin", "Flycast"),
                        listOf("Azahar", "ScummVM"),
                    ).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                            row.forEach { name ->
                                Card(
                                    modifier =
                                        Modifier
                                            .weight(1f)
                                            .height(56.dp)
                                            .then(track("Grid $name"))
                                            .clickable { },
                                ) {
                                    Text(name, modifier = Modifier.padding(12.dp))
                                }
                            }
                        }
                    }
                }
                ListItem(
                    headlineContent = { Text("Expansion — can you enter and leave?") },
                    modifier = track("Expansion").clickable { expanded = !expanded },
                )
                if (expanded) {
                    ListItem(headlineContent = { Text("Inside A") }, modifier = track("Inside A").clickable { })
                    ListItem(headlineContent = { Text("Inside B") }, modifier = track("Inside B").clickable { })
                }
                Section("Overlay — focus must not leak to the list behind")
                FilledTonalButton(onClick = { dialog = true }, modifier = track("Open dialog")) {
                    Text("Open dialog")
                }
            }
        }
    }

    if (dialog) {
        AlertDialog(
            onDismissRequest = { dialog = false },
            title = { Text("Modal") },
            text = {
                Text(
                    "Can the d-pad reach Cancel and OK? Does Back dismiss? " +
                        "When this closes, focus should return to Open dialog.",
                )
            },
            confirmButton = {
                Button(onClick = { dialog = false }, modifier = track("Dialog OK")) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { dialog = false }, modifier = track("Dialog Cancel")) { Text("Cancel") }
            },
        )
    }
}

@Composable
private fun Section(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.titleSmall,
        modifier = Modifier.padding(top = 20.dp, bottom = 8.dp),
    )
}

@Composable
private fun RadioRow(
    label: String,
    value: String,
    selected: String,
    onSelect: (String) -> Unit,
    focus: Modifier,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier =
            focus
                .fillMaxWidth()
                .selectable(selected = selected == value, onClick = { onSelect(value) }),
    ) {
        RadioButton(selected = selected == value, onClick = { onSelect(value) })
        Text(label)
    }
}
