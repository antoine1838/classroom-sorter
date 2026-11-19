import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';

/// Boîte de dialogue « saisir un texte » ; se ferme sur le texte rogné, ou sur
/// null si l'utilisateur annule :
///
/// ```dart
/// final name = await showDialog<String>(
///   context: context,
///   builder: (_) => TextPromptDialog(title: 'Nom', confirmLabel: 'OK'),
/// );
/// ```
///
/// Le contrôleur vit dans le [State] de la boîte : il est libéré avec elle, une
/// fois l'animation de fermeture finie. Le libérer juste après
/// `await showDialog` ne marcherait pas — le champ est encore à l'écran
/// pendant cette animation et lirait un contrôleur détruit.
class TextPromptDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String initial;
  final String? hint;
  final String? label;

  /// Texte d'explication affiché au-dessus du champ.
  final Widget? intro;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final InputBorder? border;

  const TextPromptDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initial = '',
    this.hint,
    this.label,
    this.intro,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.border,
  });

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  /// Hauteur max du corps : titre, actions et clavier doivent rester visibles.
  double _contentMaxHeight(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context).height;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final available = viewport - inset - 160;
    return math.max(120, math.min(320, available * 0.55));
  }

  @override
  Widget build(BuildContext context) {
    final multiline = widget.maxLines > 1;
    final field = TextField(
      controller: _controller,
      autofocus: true,
      minLines: multiline ? math.min(3, widget.maxLines) : 1,
      maxLines: widget.maxLines,
      textCapitalization: widget.textCapitalization,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        border: widget.border,
      ),
      onSubmitted: multiline ? null : (_) => _submit(),
    );
    final fieldBox = multiline
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.min(180, _contentMaxHeight(context) * 0.65),
            ),
            child: field,
          )
        : field;
    final body = widget.intro == null
        ? fieldBox
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [widget.intro!, const SizedBox(height: 8), fieldBox],
          );
    final scrollable = widget.intro != null || multiline;
    final content = SizedBox(
      width: double.maxFinite,
      child: scrollable
          ? ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _contentMaxHeight(context),
              ),
              child: SingleChildScrollView(child: body),
            )
          : body,
    );
    return AlertDialog(
      title: Text(widget.title),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
