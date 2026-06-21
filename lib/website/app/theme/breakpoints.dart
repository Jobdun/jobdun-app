/// Shared responsive breakpoints for the marketing site. One source of truth
/// so every section flips layout at the *same* widths instead of the ad-hoc
/// per-section numbers (820 / 900 / 960 / 1100) it grew. Snapping to these keeps
/// the tablet range coherent: neighbours no longer disagree on when to stack.
///
/// Tiers (width in logical px):
/// - **mobile**  `< tablet (768)`. Single column everywhere
/// - **tablet**  `[768, 960)`. 2-col card grids; split blocks still stacked
/// - **laptop**  `≥ laptop (960)`. Split blocks (text + visual) go side-by-side
/// - **desktop** `≥ desktop (1200)`. Widest page padding / max content gutter
///
/// Usage: `final w = MediaQuery.sizeOf(context).width;` then compare against
/// `Bp.laptop` etc., or use the helpers (`Bp.isMobile(w)`).
abstract final class Bp {
  /// Mobile → tablet: the 1-column ceiling.
  static const double tablet = 768;

  /// Tablet → laptop: where split (2-pane) blocks go side-by-side.
  static const double laptop = 960;

  /// Laptop → desktop: widest gutter / content tier.
  static const double desktop = 1200;

  static bool isMobile(double w) => w < tablet;
  static bool isTablet(double w) => w >= tablet && w < laptop;
  static bool isLaptopUp(double w) => w >= laptop;
  static bool isDesktop(double w) => w >= desktop;
}
