import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/l10n/generated/app_localizations.dart';
import 'package:plandeclasse/tutorial/tutorial_guide.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets('la bienvenue permet de démarrer ou de reporter le tutoriel', (
    t,
  ) async {
    bool? result;
    await t.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async => result = await showTutorialWelcome(context),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );

    await t.tap(find.text('ouvrir'));
    await t.pumpAndSettle();
    expect(find.text('Besoin d’un coup de main ?'), findsOneWidget);
    await t.tap(find.text('Pas maintenant'));
    await t.pumpAndSettle();
    expect(result, isFalse);

    await t.tap(find.text('ouvrir'));
    await t.pumpAndSettle();
    await t.tap(find.text('Démarrer le tutoriel'));
    await t.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('l’aide contextuelle couvre chaque onglet', (t) async {
    for (final entry in <TutorialTopic, ({String text, IconData icon})>{
      TutorialTopic.welcome: (
        text: 'Découvrez les quatre étapes',
        icon: Icons.school_outlined,
      ),
      TutorialTopic.home: (
        text: 'Retrouvez vos classes ici',
        icon: Icons.home_outlined,
      ),
      TutorialTopic.room: (
        text: 'Créez ou choisissez une disposition',
        icon: Icons.grid_on,
      ),
      TutorialTopic.students: (
        text: 'Ajoutez ou importez les élèves',
        icon: Icons.people_alt_outlined,
      ),
      TutorialTopic.rules: (
        text: 'Les règles définissent les contraintes',
        icon: Icons.rule_outlined,
      ),
      TutorialTopic.plan: (
        text: 'Générez un plan, consultez son rapport',
        icon: Icons.event_seat,
      ),
    }.entries) {
      await t.pumpWidget(
        _app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => showTutorialGuide(context, topic: entry.key),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );

      await t.tap(find.text('ouvrir'));
      await t.pumpAndSettle();
      expect(find.textContaining(entry.value.text), findsOneWidget);
      expect(find.byIcon(entry.value.icon), findsOneWidget);
      expect(
        find.textContaining('\n'),
        findsOneWidget,
        reason: 'une phrase par ligne, pas un bloc de texte',
      );
      final keywords = {
        TutorialTopic.home: ['historique', 'export', 'import'],
        TutorialTopic.plan: ['archiver', 'historique', 'PDF'],
      }[entry.key];
      for (final word in keywords ?? const <String>[]) {
        expect(find.textContaining(word), findsOneWidget, reason: word);
      }
      await t.tap(find.text('Fermer'));
      await t.pumpAndSettle();
    }
  });

  testWidgets(
    'le parcours essentiel avance, recule et synchronise les onglets',
    (t) async {
      await t.pumpWidget(
        _app(
          DefaultTabController(
            length: 4,
            child: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showEssentialTutorial(context),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );

      await t.tap(find.text('ouvrir'));
      await t.pumpAndSettle();
      expect(find.textContaining('salles enregistrées'), findsOneWidget);
      final body = t.widget<Text>(find.textContaining('salles enregistrées'));
      expect(
        body.textAlign,
        isNot(TextAlign.center),
        reason: 'le texte est aligné à gauche, comme dans les autres aides',
      );

      await t.tap(find.text('Suivant'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Ajoutez ou importez les élèves'),
        findsOneWidget,
      );
      expect(find.text('Précédent'), findsOneWidget);

      await t.tap(find.text('Précédent'));
      await t.pumpAndSettle();
      expect(find.textContaining('salles enregistrées'), findsOneWidget);

      for (var index = 0; index < 3; index++) {
        await t.tap(find.text('Suivant'));
        await t.pumpAndSettle();
      }
      expect(
        find.textContaining('Générez un plan, consultez son rapport'),
        findsOneWidget,
      );
      expect(find.text('Fermer'), findsOneWidget);

      await t.tap(find.text('Fermer'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Générez un plan, consultez son rapport'),
        findsNothing,
      );
    },
  );
}
