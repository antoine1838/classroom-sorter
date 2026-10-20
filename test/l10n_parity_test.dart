/// Garde-fous de traduction : `app_fr.arb` est le gabarit, `app_en.arb` doit
/// le suivre. Sans ce test, un message ajouté en français seulement retombe
/// silencieusement sur le français pour les utilisateurs anglophones.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = ['fr', 'en'];

Map<String, dynamic> _load(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Messages traduits : les clés sans `@` (métadonnées) ni `@@` (locale).
Map<String, String> _messages(Map<String, dynamic> arb) => {
  for (final entry in arb.entries)
    if (!entry.key.startsWith('@')) entry.key: entry.value as String,
};

/// Paramètres déclarés dans les métadonnées `@clé` du message.
Set<String> _declared(Map<String, dynamic> arb, String key) {
  final meta = arb['@$key'];
  if (meta is! Map<String, dynamic>) return {};
  final placeholders = meta['placeholders'];
  return placeholders is Map<String, dynamic> ? placeholders.keys.toSet() : {};
}

/// Paramètres réellement utilisés dans le texte : `{nom}` et la tête d'un
/// pluriel `{nom, plural, …}`. Le garde `(?<!\w)` écarte les branches ICU
/// comme `one{place}`, où l'accolade suit le sélecteur.
Set<String> _used(String message) => {
  for (final match in RegExp(r'(?<!\w)\{(\w+)\s*(?:\}|,)').allMatches(message))
    match.group(1)!,
};

void main() {
  final arbs = {for (final locale in _locales) locale: _load(locale)};
  final messages = {
    for (final locale in _locales) locale: _messages(arbs[locale]!),
  };

  test('le français et l anglais ont exactement les mêmes messages', () {
    final fr = messages['fr']!.keys.toSet();
    final en = messages['en']!.keys.toSet();

    expect(fr.difference(en), isEmpty, reason: 'absents de app_en.arb');
    expect(en.difference(fr), isEmpty, reason: 'absents de app_fr.arb');
  });

  test('aucun message n est vide', () {
    for (final locale in _locales) {
      messages[locale]!.forEach((key, value) {
        expect(value.trim(), isNotEmpty, reason: '$locale : $key');
      });
    }
  });

  test('chaque message déclare les mêmes paramètres dans les deux langues', () {
    for (final key in messages['fr']!.keys) {
      expect(
        _declared(arbs['en']!, key),
        _declared(arbs['fr']!, key),
        reason: key,
      );
    }
  });

  test(
    'chaque paramètre utilisé dans le texte est déclaré, et inversement',
    () {
      for (final locale in _locales) {
        messages[locale]!.forEach((key, value) {
          expect(
            _used(value),
            _declared(arbs[locale]!, key),
            reason: '$locale : $key',
          );
        });
      }
    },
  );

  test('les pluriels ont les branches one et other dans les deux langues', () {
    for (final key in messages['fr']!.keys) {
      final isPlural = _locales.any(
        (locale) => messages[locale]![key]!.contains(', plural,'),
      );
      if (!isPlural) continue;
      for (final locale in _locales) {
        final message = messages[locale]![key]!;
        expect(message, contains('one{'), reason: '$locale : $key');
        expect(message, contains('other{'), reason: '$locale : $key');
      }
    }
  });
}
