import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'core/progress_store.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await ProgressStore.open();
  runApp(NeuroNovaApp(store: store));
}

class NeuroNovaApp extends StatelessWidget {
  const NeuroNovaApp({super.key, required this.store});
  final ProgressStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NeuroNova',
    debugShowCheckedModeBanner: false,
    theme: novaTheme(),
    home: HomeScreen(store: store),
  );
}
