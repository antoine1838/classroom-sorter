import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/l10n/generated/app_localizations.dart';
import 'package:plandeclasse/screens/faq_screen.dart';

Widget _app({Locale locale = const Locale('fr')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const FaqScreen(),
);

void main() {
  testWidgets('la FAQ présente les cinq sujets initiaux', (t) async {
    await t.pumpWidget(_app());

    expect(find.text('Questions fréquentes'), findsOneWidget);
    expect(find.text('Comment gérer une AESH ?'), findsOneWidget);
    expect(
      find.text(
        'Pourquoi les prénoms ne prennent-ils pas de majuscule automatiquement ?',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Quelle est la différence entre une règle obligatoire et une préférence ?',
      ),
      findsOneWidget,
    );
    expect(
      find.text('La classe de démonstration est-elle conservée ?'),
      findsOneWidget,
    );
    expect(find.text('Où sont enregistrées mes données ?'), findsOneWidget);
  });

  testWidgets('la réponse AESH explique les règles obligatoires', (t) async {
    await t.pumpWidget(_app());

    await t.tap(find.text('Comment gérer une AESH ?'));
    await t.pumpAndSettle();

    expect(
      find.textContaining('règle obligatoire « Rapprocher »'),
      findsOneWidget,
    );
    expect(find.textContaining('jusqu’à quatre élèves'), findsOneWidget);
  });

  testWidgets('la FAQ est localisée en anglais', (t) async {
    await t.pumpWidget(_app(locale: const Locale('en')));

    expect(find.text('Frequently asked questions'), findsOneWidget);
    expect(
      find.text('How do I manage a classroom support assistant?'),
      findsOneWidget,
    );
  });
}
