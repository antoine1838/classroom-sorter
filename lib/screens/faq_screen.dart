/// Questions fréquentes, consultables sans connexion.
library;

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = [
      (question: l10n.faqAeshQuestion, answer: l10n.faqAeshAnswer),
      (
        question: l10n.faqCapitalizationQuestion,
        answer: l10n.faqCapitalizationAnswer,
      ),
      (question: l10n.faqRulesQuestion, answer: l10n.faqRulesAnswer),
      (question: l10n.faqTutorialQuestion, answer: l10n.faqTutorialAnswer),
      (question: l10n.faqDataQuestion, answer: l10n.faqDataAnswer),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.faqTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final entry in entries)
              Card(
                child: ExpansionTile(
                  title: Text(entry.question),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [Text(entry.answer)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
