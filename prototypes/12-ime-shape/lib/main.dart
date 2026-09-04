import 'package:flutter/material.dart';

import 'controller_page.dart';
import 'ime_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProtoApp());
}

class ProtoApp extends StatelessWidget {
  const ProtoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tShop prototypes',
      debugShowCheckedModeBanner: false,
      theme: protoTheme(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('tShop prototypes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProtoCard(
            autofocus: true,
            number: '#2',
            title: 'Controller input',
            body:
                'Does the d-pad arrive as keys, a hat axis, or nothing? '
                'Hold d-pad and A to measure repeats.',
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ControllerPage()),
            ),
          ),
          const SizedBox(height: 12),
          ProtoCard(
            number: '#12',
            title: 'IME shape',
            body:
                'Open the field. Does the keyboard cover the grid? '
                'Can you type with the d-pad?',
            onOpen: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const ImePage())),
          ),
        ],
      ),
    );
  }
}

class ProtoCard extends StatelessWidget {
  const ProtoCard({
    super.key,
    required this.number,
    required this.title,
    required this.body,
    required this.onOpen,
    this.autofocus = false,
  });

  final String number;
  final String title;
  final String body;
  final VoidCallback onOpen;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        autofocus: autofocus,
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                number,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: colors.primary),
              ),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(body, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

ThemeData protoTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF8EB4FF),
      brightness: Brightness.dark,
    ),
    visualDensity: VisualDensity.comfortable,
  );
}
