/// Tutoriel et aide contextuelle de l'application.
library;

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

enum TutorialTopic { welcome, home, room, students, rules, plan }

Future<bool?> showTutorialWelcome(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      icon: const Icon(Icons.school_outlined),
      title: Text(l10n.tutorialWelcomeTitle),
      content: Text(l10n.tutorialWelcomeDescription),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.tutorialSkip),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.tutorialStart),
        ),
      ],
    );
  },
);

Future<void> showTutorialGuide(
  BuildContext context, {
  required TutorialTopic topic,
  bool continuesTutorial = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) {
    final l10n = AppLocalizations.of(context)!;
    final content = _contentFor(l10n, topic);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(content.icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    content.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(content.body),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(continuesTutorial ? l10n.tutorialNext : l10n.close),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

Future<void> showEssentialTutorial(BuildContext context) {
  final topics = <TutorialTopic>[
    TutorialTopic.room,
    TutorialTopic.students,
    TutorialTopic.rules,
    TutorialTopic.plan,
  ];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      return _EssentialTutorial(
        topics: topics,
        onTopicChanged: (index) {
          DefaultTabController.maybeOf(context)?.animateTo(index);
        },
        finishLabel: l10n.close,
      );
    },
  );
}

class _EssentialTutorial extends StatefulWidget {
  const _EssentialTutorial({
    required this.topics,
    required this.onTopicChanged,
    required this.finishLabel,
  });

  final List<TutorialTopic> topics;
  final ValueChanged<int> onTopicChanged;
  final String finishLabel;

  @override
  State<_EssentialTutorial> createState() => _EssentialTutorialState();
}

class _EssentialTutorialState extends State<_EssentialTutorial> {
  final _controller = PageController();
  var _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: SizedBox(
          height: 280,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.topics.length,
                  onPageChanged: (index) {
                    setState(() => _index = index);
                    widget.onTopicChanged(index);
                  },
                  itemBuilder: (context, index) =>
                      _TutorialPage(topic: widget.topics[index]),
                ),
              ),
              Row(
                children: [
                  if (_index > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
                      child: Text(l10n.tutorialBack),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      if (_index == widget.topics.length - 1) {
                        Navigator.pop(context);
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: Text(
                      _index == widget.topics.length - 1
                          ? widget.finishLabel
                          : l10n.tutorialNext,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({required this.topic});

  final TutorialTopic topic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final content = _contentFor(l10n, topic);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(content.icon, size: 44),
            const SizedBox(height: 16),
            Text(content.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(content.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

typedef _TutorialContent = ({IconData icon, String title, String body});

_TutorialContent _contentFor(AppLocalizations l10n, TutorialTopic topic) =>
    switch (topic) {
      TutorialTopic.welcome => (
        icon: Icons.school_outlined,
        title: l10n.tutorialTitle,
        body: l10n.tutorialWelcomeDescription,
      ),
      TutorialTopic.home => (
        icon: Icons.home_outlined,
        title: l10n.myClasses,
        body: l10n.tutorialHomeDetails,
      ),
      TutorialTopic.room => (
        icon: Icons.meeting_room_outlined,
        title: l10n.roomTab,
        body: l10n.tutorialRoomDetails,
      ),
      TutorialTopic.students => (
        icon: Icons.people_alt_outlined,
        title: l10n.studentsTab,
        body: l10n.tutorialStudentsDetails,
      ),
      TutorialTopic.rules => (
        icon: Icons.rule_outlined,
        title: l10n.rulesTab,
        body: l10n.tutorialRulesDetails,
      ),
      TutorialTopic.plan => (
        icon: Icons.event_seat_outlined,
        title: l10n.planTab,
        body: l10n.tutorialPlanDetails,
      ),
    };
