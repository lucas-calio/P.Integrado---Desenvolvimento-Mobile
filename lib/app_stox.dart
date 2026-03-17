import 'package:flutter/material.dart';

import 'src/pages/login_page.dart';
import 'src/widgets/stox_theme.dart';

/// Raiz da aplicação STOX.
///
/// Configura o [MaterialApp] com o tema SAP Fiori ([StoxTheme.lightTheme])
/// e define [LoginPage] como rota inicial.
class StoxApp extends StatelessWidget {
  const StoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                  'STOX - Inventário',
      debugShowCheckedModeBanner: false,
      theme:                  StoxTheme.lightTheme,
      home:                   const LoginPage(),
    );
  }
}