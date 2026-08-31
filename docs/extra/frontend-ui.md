# UI neumorphique

Fond et cartes **même couleur** ; le relief = deux ombres (clair + sombre). Tokens dans `lib/core/theme/app_theme.dart` via `ThemeExtension<AppDesignTokens>`.

- Light bg : `#E0EAE5`
- Dark bg : `#121A14`
- `neumorphicShadow` : élevé ; `neumorphicPressedShadow` : enfoncé

```dart
final tokens = Theme.of(context).extension<AppDesignTokens>()!;
BoxDecoration(
  color: Theme.of(context).scaffoldBackgroundColor,
  borderRadius: tokens.cardRadius,
  boxShadow: tokens.neumorphicShadow,
);
```
