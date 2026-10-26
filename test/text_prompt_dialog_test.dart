// Le dialogue « saisir un texte » partagé par six écrans : il rend le texte
// rogné, et il libère son contrôleur une fois fermé.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/l10n/generated/app_localizations.dart';
import 'package:plandeclasse/widgets/text_prompt_dialog.dart';

/// Monte un bouton qui ouvre le dialogue ; [result] recueille ce qu'il rend.
Future<void> _pump(
  WidgetTester tester, {
  required void Function(String?) result,
  String initial = '',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result(
            await showDialog<String>(
              context: context,
              builder: (_) => TextPromptDialog(
                title: 'Nom',
                confirmLabel: 'Créer',
                initial: initial,
              ),
            ),
          ),
          child: const Text('ouvrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rend le texte saisi, sans les espaces autour', (tester) async {
    String? result;
    await _pump(tester, result: (v) => result = v);

    await tester.enterText(find.byType(TextField), '  6ème B  ');
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    expect(result, '6ème B');
  });

  testWidgets('Entrée valide comme le bouton', (tester) async {
    String? result;
    await _pump(tester, result: (v) => result = v);

    await tester.enterText(find.byType(TextField), '5ème A');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(result, '5ème A');
  });

  testWidgets('annuler ne rend rien', (tester) async {
    String? result = 'inchangé';
    await _pump(tester, result: (v) => result = v);

    await tester.enterText(find.byType(TextField), 'perdu');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('le champ part de la valeur initiale', (tester) async {
    await _pump(tester, result: (_) {}, initial: 'Salle 12');

    expect(find.widgetWithText(TextField, 'Salle 12'), findsOneWidget);
  });

  testWidgets('le contrôleur est libéré avec le dialogue', (tester) async {
    await _pump(tester, result: (_) {});
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    // Un ChangeNotifier libéré refuse tout nouvel écouteur.
    expect(() => controller.addListener(() {}), throwsFlutterError);
  });
}
