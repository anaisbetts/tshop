package dev.anais.tshop.composeuitests

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(onOpen: (Screen) -> Unit) {
    Scaffold(
        topBar = { TopAppBar(title = { Text("tShop prototypes") }) },
    ) { padding ->
        LazyColumn(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                ProtoCard(
                    number = "#2",
                    title = "Controller input",
                    body =
                        "Does the d-pad arrive as keys, a hat axis, or nothing? " +
                            "Hold d-pad and A to measure repeats.",
                    onOpen = { onOpen(Screen.Controller) },
                )
            }
            item {
                ProtoCard(
                    number = "Focus",
                    title = "Widget focus",
                    body =
                        "D-pad through stock Material3 controls. " +
                            "This is default Compose on a handheld — no TV library.",
                    onOpen = { onOpen(Screen.FocusKitchen) },
                )
            }
            item {
                ProtoCard(
                    number = "#12",
                    title = "IME shape",
                    body =
                        "Open the field. Does the keyboard cover the grid? " +
                            "Can you type with the d-pad?",
                    onOpen = { onOpen(Screen.Ime) },
                )
            }
        }
    }
}

@Composable
private fun ProtoCard(
    number: String,
    title: String,
    body: String,
    onOpen: () -> Unit,
) {
    Card(
        modifier =
            Modifier
                .fillMaxWidth()
                .clickable(onClick = onOpen),
    ) {
        Column(Modifier.padding(20.dp)) {
            Text(number, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
            Text(title, style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(top = 4.dp))
            Text(body, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(top = 8.dp))
        }
    }
}
