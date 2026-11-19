# Checklist visuelle — migration `material_ui` (PR 1)

À valider **avant merge** (claire + sombre, Windows + Web recommandés).

## Goldens (`flutter test test/golden_grids_test.dart`)

- `plan_portrait` — Plan, portrait
- `plan_paysage` — Plan, paysage
- `plan_problemes` — sévérité des places (clair)
- `plan_problemes_sombre` — sévérité (sombre)
- `salle_u` — éditeur de salle (U, couloirs, dossiers)

Ne régénérer (`--update-goldens`) qu’après validation visuelle des écarts.

## Parcours manuels

1. Accueil (liste, FAB, import, démo, aide, réglages, bannière persistance)
2. Création de classe + choix de disposition
3. Onglets Salle / Élèves / Règles / Plan
4. Plan : zoom, rapport, archive, historique, export PDF, D&D, détail élève
5. Réglages : langue, thème, palette, vue élèves
6. Historique, FAQ, tutoriel / aides par onglet
7. Dialogues (suppression, confidentialité export, archivage)
8. Import / export `.planclasse`, export PDF
9. Fenêtre desktop (taille, position)

## Audit deps (transitif)

| Package | État app | Note |
|---------|----------|------|
| `file_picker` | MAJ transitive via `pub get` | `saveFile` sans paramètres dépréciés |
| `printing` | Legacy Material **dans** le plugin | Pas de bridge ; tests export PDF OK |
| `window_manager` | 0.7 + `legacy.dart` dans `desktop_window_io.dart` uniquement | Pas d’import direct dans `main.dart` (build Web) ; tests fenêtre OK |

`printing` : pas de bump majeur dans cette vague (hors scope).