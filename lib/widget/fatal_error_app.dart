import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:viro_team/pages/fatal_error_page.dart';
import 'package:viro_team/theme/viro_theme.dart';

/// Application minimale affichée en cas d'erreur fatale lors de l'initialisation
class FatalErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;

  const FatalErrorApp({
    super.key,
    required this.error,
    this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ViroTeam - Erreur',
      theme: ViroTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FatalErrorPage(
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}
