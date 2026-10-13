# Captures Play : outillage

Les captures `store/play/metadata/fr-FR/screenshots/` (fr) et `store/play/metadata/en-US/screenshots/` (en) sont prises sur le **build Windows**, pas sur Android.

1. `git apply store/play/tools/screenshot-hooks.patch` : hooks temporaires pilotés par variables `PDC_SHOT_*` (classe de démo en mémoire, thème clair forcé, langue, vue Élèves, disposition en îlots, place en violation, feuille de détail). Rien n'est persisté. Si le patch ne s'applique plus, relire `lib/main.dart`, `class_editor_screen.dart` et `class_editor/plan_tab.dart` et le refaire à la main.
2. `flutter build windows --debug`.
3. **Fermer Teams et toute fenêtre sensible**, puis, depuis la racine du dépôt, dans PowerShell :
   `.\store\play\tools\capture-all.ps1 -Locale fr -OutDir <dossier>` (idem `-Locale en`).
   `capture.ps1` prend une capture seule (voir ses paramètres). Elle vise le moniteur **portrait**, dimensionne la zone client en 1080x1920 (1920x1080 avec `-Width/-Height`) et force la fenêtre au premier plan.
4. **Relire chaque image** : une fenêtre étrangère devant l'appli est capturée telle quelle.
5. `git apply -R store/play/tools/screenshot-hooks.patch`, puis copier les PNG.

Pièges : le script est lu sans BOM par Windows PowerShell 5.1 (rester en ASCII dans les chaînes qui comptent) ; les lignes d'état « OK » ne prouvent pas que la capture est propre.
