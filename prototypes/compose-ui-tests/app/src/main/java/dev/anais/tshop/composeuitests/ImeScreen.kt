package dev.anais.tshop.composeuitests

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.ime

val CATALOG = listOf(
    "PPSSPP",
    "RetroArch",
    "Dolphin",
    "Flycast",
    "Azahar",
    "MelonDS",
    "DuckStation",
    "ScummVM",
    "Vita3K",
    "Play!",
    "Eden",
    "Redream",
    "M64Plus FZ",
    "NetherSX2",
    "Lemuroid",
    "Pegasus",
    "Daijisho",
    "RetroArch 32",
    "PPSSPP Gold",
    "AetherSX2",
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ImeScreen(onBack: () -> Unit) {
    var query by remember { mutableStateOf("") }
    val window = LocalWindowInfo.current.containerSize
    val imeBottom = WindowInsets.ime.getBottom(LocalDensity.current).toFloat()
    val remaining = window.height - imeBottom
    val visible = gridRemainsVisible(remaining)
    val tiles = CATALOG.filter { it.contains(query, ignoreCase = true) }
    val ratio = window.width.toFloat() / window.height.toFloat()
    val verdict = when {
        imeBottom <= 0f -> "NO IME"
        visible -> "DOCKS — grid visible"
        else -> "COVERS — grid hidden"
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("#12 IME shape") },
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
                .padding(padding)
                .imePadding(),
        ) {
            Surface(
                color = if (visible || imeBottom <= 0f) {
                    MaterialTheme.colorScheme.surfaceContainerHigh
                } else {
                    MaterialTheme.colorScheme.errorContainer
                },
            ) {
                Column(Modifier.padding(12.dp)) {
                    Text(verdict, style = MaterialTheme.typography.headlineSmall)
                    Text(
                        "${window.width}×${window.height}  ${"%.2f".format(ratio)}  " +
                            "inset ${imeBottom.toInt()}  remain ${remaining.toInt()}",
                    )
                    Text("Photograph with the keyboard open. If this grid is gone, IME is fullscreen.")
                }
            }
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(16.dp, 8.dp),
                label = { Text("Search") },
                placeholder = { Text("Type with the d-pad if you can") },
                singleLine = true,
            )
            LazyVerticalGrid(
                columns = GridCells.Adaptive(160.dp),
                modifier = Modifier.fillMaxSize().padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(tiles) { name ->
                    Card(modifier = Modifier.aspectRatio(1f)) {
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text(name, style = MaterialTheme.typography.titleMedium)
                        }
                    }
                }
            }
        }
    }
}
