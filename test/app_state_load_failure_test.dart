// Démarrage avec des données partiellement ou totalement illisibles : une
// erreur de lecture doit se voir (bandeau) et ne doit jamais laisser l'écran de
// chargement tourner sans fin, ni conduire à écraser ce qu'on n'a pas pu lire.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/l10n/generated/app_localizations.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/screens/home_screen.dart';

const _classesKey = 'plandeclasse_classes_v1';
const _tutorialSeenKey = 'plandeclasse_tutorial_seen_v1';

Map<String, dynamic> _brokenClass(String id) => {
  ...ClassGroup(id: id, name: 'Cassée $id').toJson(),
  'snapshots': [
    {
      'id': 's',
      'label': 'Trimestre 1',
      'createdAt': 'pas une date',
      'schemaVersion': 1,
      'classData': <String, dynamic>{},
    },
  ],
};

String _partialClasses(int broken) => jsonEncode([
  ClassGroup(id: 'a', name: '6ème A').toJson(),
  for (var i = 0; i < broken; i++) _brokenClass('b$i'),
]);

void main() {
  group('AppState.init', () {
    test('des classes illisibles sont comptées et signalées', () async {
      SharedPreferences.setMockInitialValues({_classesKey: _partialClasses(2)});
      final state = AppState();

      await state.init();

      expect(state.loading, isFalse);
      expect(state.classes.map((c) => c.name), ['6ème A']);
      expect(state.skippedClassCount, 2);
      expect(state.persistenceNotices, [PersistenceNotice.classesPartial]);
      expect(state.persistenceMessageIsError, isTrue);
      expect(state.loadFailed, isFalse);
    });

    test(
      'un stockage illisible ne laisse pas le chargement tourner sans fin',
      () async {
        // Un entier là où l'application a toujours écrit du texte : la lecture
        // lève. Avant, `init()` n'était pas protégé et `loading` restait vrai.
        SharedPreferences.setMockInitialValues({_classesKey: 42});
        final state = AppState();

        await state.init();

        expect(state.loading, isFalse);
        expect(state.loadFailed, isTrue);
        expect(state.classes, isEmpty);
        expect(state.persistenceNotices, [PersistenceNotice.loadFailed]);
        expect(state.persistenceMessageIsError, isTrue);
      },
    );

    test('après un échec de lecture, rien n\'écrase les données', () async {
      SharedPreferences.setMockInitialValues({_classesKey: 42});
      final state = AppState();
      await state.init();

      state.addClass('Nouvelle classe');
      await state.flushPendingSaves();
      final prefs = await SharedPreferences.getInstance();

      expect(
        prefs.get(_classesKey),
        42,
        reason: 'la valeur que l\'on n\'a pas pu lire doit rester en place',
      );
      expect(state.persistenceNotices, [PersistenceNotice.loadFailed]);
    });

    test(
      'après un échec de lecture, les réglages restent enregistrés',
      () async {
        SharedPreferences.setMockInitialValues({_classesKey: 42});
        final state = AppState();
        await state.init();

        state.setThemePreference(ThemePreference.dark);
        await state.flushPendingSaves();
        final prefs = await SharedPreferences.getInstance();

        expect(prefs.getString('plandeclasse_theme_preference_v1'), 'dark');
      },
    );

    test('des données saines ne produisent aucun avertissement', () async {
      SharedPreferences.setMockInitialValues({_classesKey: _partialClasses(0)});
      final state = AppState();

      await state.init();

      expect(state.persistenceNotices, isEmpty);
      expect(state.skippedClassCount, 0);
      expect(state.loadFailed, isFalse);
    });
  });

  group('bandeau de l\'accueil', () {
    Future<void> pumpHome(
      WidgetTester tester,
      Map<String, Object> prefs, {
      Locale locale = const Locale('fr'),
    }) async {
      SharedPreferences.setMockInitialValues({
        _tutorialSeenKey: true,
        ...prefs,
      });
      final state = AppState();
      await tester.runAsync(state.init);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(state: state),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('une classe illisible : le texte la compte (singulier)', (
      tester,
    ) async {
      await pumpHome(tester, {_classesKey: _partialClasses(1)});

      expect(
        find.textContaining('1 classe était illisible et n’a pas été chargée'),
        findsOneWidget,
      );
      expect(find.textContaining('Les autres sont intactes'), findsOneWidget);
    });

    testWidgets(
      'plusieurs classes illisibles : le texte les compte (pluriel)',
      (tester) async {
        await pumpHome(tester, {_classesKey: _partialClasses(3)});

        expect(
          find.textContaining(
            '3 classes étaient illisibles et n’ont pas été chargées',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('en anglais aussi', (tester) async {
      await pumpHome(tester, {
        _classesKey: _partialClasses(2),
      }, locale: const Locale('en'));

      expect(
        find.textContaining('2 classes were unreadable and were not loaded'),
        findsOneWidget,
      );
    });

    testWidgets(
      'un stockage illisible : le texte explique que rien ne sera écrit',
      (tester) async {
        await pumpHome(tester, {_classesKey: 42});

        expect(find.textContaining('Pour ne pas les écraser'), findsOneWidget);
        expect(find.text('Mes classes'), findsOneWidget);
      },
    );
  });
}
