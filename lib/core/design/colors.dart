/// Design-system token barrel — the one entry point feature files should
/// use when reaching for colours, spacing, radii, or motion tokens.
///
/// **Why this exists.** Feature files used to import
/// `lib/app/theme/app_colors.dart` directly to pick up `JColors`, `JColorsX`,
/// `AppSpacing`, and `AppRadius`. That tangle made the design-system CI
/// lint impossible to write — banning `app_colors.dart` would also ban the
/// `context.c` extension. This barrel separates the two concerns so the
/// lint can target the source files (`app/theme/app_*.dart`) and let
/// features import the public surface.
///
/// **Usage:**
/// ```dart
/// import 'package:jobdun/core/design/colors.dart';
/// // gives you: JColors, JColorsX, AppSpacing, AppRadius, AppMotion
/// ```
///
/// **Migration.** Sprint B (task B9) moves every feature file over from the
/// individual theme files to this barrel. Until then the legacy imports
/// continue to work because `app_colors.dart` re-exports the same symbols.
library;

export 'package:jobdun/app/theme/app_colors.dart' show JColors, JColorsX;
export 'package:jobdun/app/theme/app_motion.dart' show AppMotion;
export 'package:jobdun/app/theme/app_radii.dart' show AppRadius;
export 'package:jobdun/app/theme/app_spacing.dart' show AppSpacing;
