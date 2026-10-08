/// Éditeur d'une classe : 4 onglets — Salle, Élèves, Règles, Plan.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../actions/class_group_ops.dart';
import '../app_state.dart';
import '../engine/plan_evaluation_signature.dart';
import '../engine/plan_generation.dart';
import '../engine/plan_issue.dart';
import '../engine/seating_engine.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/generated/app_localizations_fr.dart';
import '../l10n/plan_issue_localizations.dart';
import '../models/classroom.dart';
import '../models/room.dart';
import '../models/room_layouts.dart';
import '../models/rule.dart';
import '../models/saved_room.dart';
import '../models/student.dart';
import '../widgets/plan_viewport.dart';
import '../widgets/room_thumbnail.dart';
import '../widgets/seat_grid.dart';

part 'class_editor/room_tab.dart';
part 'class_editor/students_tab.dart';
part 'class_editor/rules_tab.dart';
part 'class_editor/plan_tab.dart';

/// Uses French as a safe fallback for isolated widget tests that mount this
/// screen without the application's localization delegates.
AppLocalizations _l10n(BuildContext context) =>
    _ClassEditorLocalizations.maybeOf(context) ??
    AppLocalizations.of(context) ??
    AppLocalizationsFr();

class _ClassEditorLocalizations extends InheritedWidget {
  const _ClassEditorLocalizations({
    required this.localizations,
    required super.child,
  });

  final AppLocalizations localizations;

  static AppLocalizations? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ClassEditorLocalizations>()
      ?.localizations;

  @override
  bool updateShouldNotify(_ClassEditorLocalizations oldWidget) =>
      localizations != oldWidget.localizations;
}

/// Le contrôle qui ouvre le rapport, quelle que soit la disposition.
const kReportButtonKey = Key('plan-report-button');

/// Le retour affiché à côté des onglets quand l'app bar est masquée.
const kClassBackKey = Key('class-back');

/// La barre fine qui porte le nom de la classe quand l'app bar est masquée.
const kClassNameBarKey = Key('class-name-bar');

/// Les quatre onglets de l'écran, dans l'ordre.
/// French defaults retained for layout-focused tests.
const kClassTabs = <({IconData icon, String label})>[
  (icon: Icons.grid_on, label: 'Salle'),
  (icon: Icons.people_alt_outlined, label: 'Élèves'),
  (icon: Icons.rule, label: 'Règles'),
  (icon: Icons.event_seat, label: 'Plan'),
];

List<({IconData icon, String label})> _classTabs(AppLocalizations l10n) => [
  (icon: Icons.grid_on, label: l10n.roomTab),
  (icon: Icons.people_alt_outlined, label: l10n.studentsTab),
  (icon: Icons.rule, label: l10n.rulesTab),
  (icon: Icons.event_seat, label: l10n.planTab),
];

/// Largeur du bouton retour, et respiration minimale autour d'un libellé
/// d'onglet.
const double _kBackButtonWidth = 48;

/// Padding interne d'un [Tab] de chaque côté de son contenu
/// (`kTabLabelPadding` dans le code source de Flutter = 16dp par côté, donc
/// 32 au total). Mesuré en trouvant le seuil réel de clip par test : une
/// première valeur à 16 (un seul côté) faisait basculer le palier trop tard,
/// les libellés larges (« Élèves », « Règles ») restant coupés net alors que
/// le calcul les croyait déjà casés.
const double _kTabLabelBreathing = 32;

/// Vrai si les libellés des onglets tiennent en entier dans [width].
///
/// Mesuré, comme les boutons du plan : tronqués à « Sa », « Élè », « Rè », ils ne
/// renseignent plus personne, et les quatre icônes sont distinctes. Autant
/// rendre cette largeur au nom de la classe.
bool _tabLabelsFit(BuildContext context, double width) {
  final style = Theme.of(context).textTheme.labelLarge;
  var widest = 0.0;
  for (final tab in _classTabs(_l10n(context))) {
    final painter = TextPainter(
      text: TextSpan(text: tab.label, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    widest = max(widest, painter.width);
  }
  return width >=
      _kBackButtonWidth +
          _classTabs(_l10n(context)).length * (widest + _kTabLabelBreathing);
}

/// Nom de la classe sur une ligne fine, au-dessus des onglets.
///
/// Toute la barre est tappable pour renommer : un [IconButton] fait 48 dp, il ne
/// tiendrait pas dans cette hauteur. La cible devient donc large et basse plutôt
/// que carrée, et le crayon n'est qu'un indice visuel.
///
/// Le nom est centré sur toute la largeur de la barre, pas seulement dans
/// l'espace qui reste après le crayon : une réserve invisible de la même
/// largeur équilibre le crayon de l'autre côté, sans quoi le centrage ne serait
/// que visuel d'un côté et le nom paraîtrait décalé vers la gauche.
class _ClassNameBar extends StatelessWidget {
  const _ClassNameBar({
    required this.state,
    required this.cls,
    required this.onRename,
  });

  final AppState state;
  final ClassGroup cls;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      key: kClassNameBarKey,
      color: cs.surfaceContainerLow,
      child: InkWell(
        onTap: onRename,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            children: [
              // Réserve invisible de la même largeur que le crayon, pour que le
              // nom se centre sur toute la barre plutôt que sur l'espace qui
              // reste à sa gauche.
              const SizedBox(width: 14),
              Expanded(
                child: ListenableBuilder(
                  listenable: state,
                  builder: (_, _) => Text(
                    cls.name.isEmpty
                        ? _l10n(context).classDefaultName
                        : cls.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Même police que les onglets : les onglets Material 3
                    // utilisent titleSmall (vérifié dans tabs.dart).
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              Icon(Icons.edit_outlined, size: 14, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quels libellés la barre de commandes du plan peut afficher.
///
/// Trois paliers plutôt que deux : le rapport est secondaire, donc il perd son
/// libellé avant les commandes principales. Sur un téléphone en portrait, cela
/// permet de garder « Régénérer » et « Valider » écrits en clair.
enum _PlanLabels { all, mainOnly, none }

/// Ce qu'un bouton à libellé consomme AUTOUR de son texte : marges internes,
/// icône et son espacement. Le texte, lui, est mesuré — pas estimé.
const double _kButtonOverhead = 66;

/// Largeur d'un bouton réduit à son icône.
const double _kIconMinW = 48;

const double _kPlanBarPadding = 24;
const double _kPlanBarGap = 8;

/// Couleur d'un plan irréprochable, et celle des points perfectibles : ni
/// l'erreur, ni le vert. Reprennent le vert et l'orange déjà employés par les
/// lignes du rapport.
final Color _kSoftColour = Colors.orange.shade700;
const Color _kCleanColour = Colors.green;

/// Largeur qu'occuperait un bouton portant ce libellé.
///
/// Mesurée avec un [TextPainter] plutôt qu'estimée : des minimums au doigt
/// mouillé faisaient basculer les paliers trop tôt, alors qu'il restait
/// visiblement de la place dans les boutons.
double _labelledWidth(BuildContext context, String label) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: Theme.of(context).textTheme.labelLarge),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width + _kButtonOverhead;
}

/// Hauteur qu'occuperait [text] replié sur [maxWidth] : mesurée avec un
/// [TextPainter], comme [_labelledWidth] le fait pour une largeur — un
/// paragraphe fixe n'a pas une hauteur fixe, elle dépend de la place restante.
double _wrappedTextHeight(
  BuildContext context,
  String text,
  TextStyle? style,
  double maxWidth,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: maxWidth < 0 ? 0 : maxWidth);
  return painter.height;
}

/// Ce que coûte chaque élément de chrome vertical, au-dessus de la grille.
///
/// Il n'y a plus d'app bar : le nom de la classe vit sur sa propre barre fine,
/// permanente, et le retour à gauche des onglets. Une seule disposition à
/// toutes les tailles, et 56 dp rendus à la grille sur TOUS les formats.
const double _kNameBarHeight = 30;
const double _kTabsHeight = 72;
const double _kButtonRowHeight = 64;
const double _kPlanPadding = 24;

/// Hauteur en dessous de laquelle la grille — ou, par réutilisation, le
/// tableau des élèves — cesse d'être lisible. Sert de seuil de dégradation
/// pour les onglets Plan, Salle et Élèves (voir #17).
const double _kMinGridHeight = 320;

/// Rapport largeur/hauteur à partir duquel la largeur est franchement l'axe
/// abondant, et un rail latéral vaut la peine.
const double _kWideRatio = 1.2;

/// Vrai si les commandes du plan doivent passer dans un rail latéral.
///
/// C'est le seul arbitrage qui reste : le rail échange de la largeur, souvent
/// abondante, contre de la hauteur, souvent rare.
bool planUsesRail(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final insets = MediaQuery.paddingOf(context).vertical;
  final free =
      size.height -
      insets -
      _kNameBarHeight -
      _kTabsHeight -
      _kButtonRowHeight -
      _kPlanPadding;
  if (free >= _kMinGridHeight) return false;

  // Un rail n'a de sens que si la largeur est l'axe franchement ABONDANT. Dans
  // une fenêtre portrait, c'est elle qui est rare : un rail y volerait
  // précisément la ressource qui manque.
  //
  // La marge de [_kWideRatio] n'est pas décorative : sans elle, une fenêtre
  // presque carrée bascule d'une disposition à l'autre au pixel près, ce qui
  // donne une impression d'arbitraire au redimensionnement.
  return size.width >= size.height * _kWideRatio;
}

/// Vrai si la fenêtre ressemble à un téléphone tourné en paysage — pas juste
/// « plus large que haut », ce qu'une fenêtre de bureau est presque
/// toujours : il faut aussi une hauteur franchement réduite, celle où les
/// boutons virtuels Android (One UI notamment) peuvent réellement se
/// retrouver sur le côté plutôt qu'en bas (voir #11, et la même mise en garde
/// pour [planUsesRail]).
bool _looksLikeLandscapePhone(Size size) =>
    size.width > size.height && size.height < 500;

class ClassEditorScreen extends StatelessWidget {
  final AppState state;
  final ClassGroup cls;
  final PlanGenerator? planGenerator;
  const ClassEditorScreen({
    super.key,
    required this.state,
    required this.cls,
    this.planGenerator,
  });

  /// Les quatre onglets, avec ou sans libellés.
  ///
  /// Sans libellé, un [Tab] fait 46 dp de haut au lieu de 72 : les 26 dp gagnés
  /// paient presque entièrement la barre du nom de classe.
  static TabBar _tabsFor(
    BuildContext context, {
    required bool labels,
  }) => TabBar(
    // Non scrollable : les 4 onglets se répartissent sur toute la largeur de
    // l'écran (adaptatif), sans défilement ni espace vide.
    isScrollable: false,
    tabs: [
      for (final t in _classTabs(_l10n(context)))
        labels
            ? Tab(icon: Icon(t.icon), text: t.label)
            // Sans libellé visible, l'icône seule ne dit plus son nom :
            // un Tooltip porte le texte qui vient de disparaître.
            : Tab(
                icon: Tooltip(message: t.label, child: Icon(t.icon)),
              ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // Plus d'app bar : une seule disposition à toutes les tailles. Le nom de
    // la classe vit sur sa barre fine, permanente, et le retour à gauche des
    // onglets — l'arrangement retenu après essai. 56 dp rendus à la grille
    // sur tous les formats, y compris le bureau.
    // Plancher = hauteur d'une barre de navigation Android standard. Sur
    // certains Samsung (One UI, boutons transparents), l'inset système remonté
    // par l'OS est nul ou sous-évalué : le SafeArea seul laisse alors le
    // dernier élève sous les boutons logiciels (issue #11). `minimum` ne mord
    // que si l'inset réel est plus petit que lui — un appareil qui remonte un
    // inset correct n'y perd donc rien.
    //
    // Ces boutons suivent la rotation physique de l'écran : en paysage ils se
    // retrouvent sur le bord gauche ou droit, pas en bas — réserver `bottom`
    // dans ce cas ne protège rien et vole en pure perte la hauteur, déjà rare
    // en paysage (constaté : régression du test du Plan en paysage téléphone).
    final navBarMinimum = _looksLikeLandscapePhone(MediaQuery.sizeOf(context))
        ? const EdgeInsets.only(left: 48, right: 48)
        : const EdgeInsets.only(bottom: 48);
    final l10n = _l10n(context);
    return _ClassEditorLocalizations(
      localizations: l10n,
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          body: SafeArea(
            minimum: navBarMinimum,
            child: Column(
              children: [
                _ClassNameBar(
                  state: state,
                  cls: cls,
                  onRename: () => _rename(context),
                ),
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        BackButton(
                          key: kClassBackKey,
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        Expanded(
                          child: _tabsFor(
                            context,
                            labels: _tabLabelsFit(
                              context,
                              constraints.maxWidth,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: state,
                    builder: (context, _) => TabBarView(
                      children: [
                        _RoomTab(state: state, cls: cls),
                        _StudentsTab(state: state, cls: cls),
                        _RulesTab(state: state, cls: cls),
                        _PlanTab(
                          state: state,
                          cls: cls,
                          planGenerator:
                              planGenerator ??
                              const PlanGenerationService().generate,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final ctrl = TextEditingController(text: cls.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_l10n(context).renameClass),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_l10n(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(_l10n(context).ok),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      ClassGroupOps(cls, commit: state.touch).rename(name);
    }
  }
}

// ---------------------------------------------------------------------------
// Petit composant : incrément / décrément avec libellé.
// ---------------------------------------------------------------------------

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.outlined(
              onPressed: onMinus,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 34,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton.outlined(onPressed: onPlus, icon: const Icon(Icons.add)),
          ],
        ),
      ],
    );
  }
}
