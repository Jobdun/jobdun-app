import 'package:flutter/widgets.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

/// Semantic icon catalogue for Jobdun.
///
/// Every widget references `AppIcons.<concept>`, NEVER the Tabler import
/// directly. This decouples our domain vocabulary from the icon library:
/// swapping libraries later changes this one file, not 200 call-sites.
///
/// Library: `flutter_tabler_icons` (Tabler), substituted for the spec's
/// `tabler_icons_flutter` — that port caps at Dart `<3.0.0` and cannot
/// resolve on this project's Dart 3.11.5. `flutter_tabler_icons` exposes the
/// same `TablerIcons.<snake_case>` API the spec assumes.
///
/// A `({outline, filled})` record models the navigation pairs (inactive vs
/// active glyph). Everything else is a single [IconData].
class AppIcons {
  AppIcons._();

  // ───── Navigation (outline + filled pairs) ─────
  static const home = (
    outline: TablerIcons.home,
    filled: TablerIcons.home_filled,
  );
  static const findJobs = (
    outline: TablerIcons.briefcase,
    filled: TablerIcons.briefcase_filled,
  );
  // No filled `checklist` glyph in Tabler — active state is conveyed via
  // colour/weight (see AppSelection), so outline == filled here.
  static const applied = (
    outline: TablerIcons.checklist,
    filled: TablerIcons.checklist,
  );
  static const messages = (
    outline: TablerIcons.message_circle,
    filled: TablerIcons.message_circle_filled,
  );
  static const profile = (
    outline: TablerIcons.user,
    filled: TablerIcons.user_filled,
  );

  // ───── Domain (Jobdun-specific concepts) ─────
  static const verified = TablerIcons.shield_check;
  static const licence = TablerIcons.id_badge_2;
  static const trade = TablerIcons.tool;
  static const builder = TablerIcons.building;
  static const location = TablerIcons.map_pin;
  static const locationFilled = TablerIcons.map_pin_filled;
  static const budget = TablerIcons.cash;
  static const calendar = TablerIcons.calendar;
  static const clock = TablerIcons.clock;
  static const insurance = TablerIcons.shield;
  static const abn = TablerIcons.file_certificate;
  static const document = TablerIcons.file_text;

  // ───── Actions ─────
  static const search = TablerIcons.search;
  static const filter = TablerIcons.adjustments_horizontal;
  static const sort = TablerIcons.arrows_sort;
  static const post = TablerIcons.plus;
  static const addCircle = TablerIcons.circle_plus;
  static const addBox = TablerIcons.square_plus;
  static const edit = TablerIcons.pencil;
  static const editProfile = TablerIcons.user_edit;
  static const delete = TablerIcons.trash;
  static const share = TablerIcons.share;
  static const save = TablerIcons.bookmark;
  static const saved = TablerIcons.bookmark_filled;
  static const close = TablerIcons.x;
  static const closeCircle = TablerIcons.circle_x;
  static const back = TablerIcons.arrow_left;
  static const forward = TablerIcons.arrow_right;
  static const expand = TablerIcons.chevron_down;
  static const collapse = TablerIcons.chevron_up;
  static const more = TablerIcons.dots_vertical;
  static const refresh = TablerIcons.refresh;
  static const send = TablerIcons.send;

  // ───── Status ─────
  static const success = TablerIcons.circle_check;
  static const error = TablerIcons.alert_circle;
  static const warning = TablerIcons.alert_triangle;
  static const info = TablerIcons.info_circle;
  static const pending = TablerIcons.hourglass;

  // ───── Auth / Account ─────
  static const email = TablerIcons.mail;
  static const emailAlert = TablerIcons.mail_exclamation;
  static const password = TablerIcons.lock;
  static const visible = TablerIcons.eye;
  static const hidden = TablerIcons.eye_off;
  static const google = TablerIcons.brand_google;
  static const apple = TablerIcons.brand_apple;
  static const logout = TablerIcons.logout;

  // ───── Settings / Legal ─────
  static const settings = TablerIcons.settings;
  static const notifications = TablerIcons.bell;
  static const help = TablerIcons.help;
  static const legal = TablerIcons.scale;
  static const privacy = TablerIcons.lock;

  // ───── Communication ─────
  static const phone = TablerIcons.phone;
  static const chat = TablerIcons.message_circle;

  // ───── Misc ─────
  // Concepts pulled in by existing call-sites that had no clean entry in the
  // initial catalogue. Add here rather than importing Tabler at the usage.
  static const rating = TablerIcons.star; // profile / job star
  static const ratingFilled = TablerIcons.star_filled; // filled star
  static const favorite = TablerIcons.heart; // saved / like (outline)
  static const favoriteFilled = TablerIcons.heart_filled; // saved (filled)
  static const image = TablerIcons.photo; // gallery / portfolio
  static const imageError = TablerIcons.photo_off; // broken/empty image
  static const camera = TablerIcons.camera; // capture avatar/doc
  static const card = TablerIcons.credit_card; // payment card
  static const receipt = TablerIcons.receipt; // invoice / earnings
  static const award = TablerIcons.award; // badges / achievements
  static const archive = TablerIcons.archive; // legal index / archive
  static const quote = TablerIcons.quote; // logo-compare testimonial
  static const map = TablerIcons.map; // job feed map view
  static const gridView = TablerIcons.layout_grid; // job feed grid view
  static const flash = TablerIcons.bolt; // speed / instant emphasis
  // The old resize glyph was used only as a neutral placeholder on the
  // profile placeholder page — `dimensions` is the closest Tabler glyph.
  static const size = TablerIcons.dimensions;
  static const wifi = TablerIcons.wifi; // connectivity banner
  static const lightMode = TablerIcons.sun; // theme toggle
  static const darkMode = TablerIcons.moon; // theme toggle

  /// Flat registry of every glyph above, used by the smoke test and the
  /// `/dev/icons` preview gallery. Nav pairs are flattened into two rows.
  static const List<({String group, String name, IconData icon})> catalogue = [
    (group: 'Navigation', name: 'home (outline)', icon: TablerIcons.home),
    (group: 'Navigation', name: 'home (filled)', icon: TablerIcons.home_filled),
    (
      group: 'Navigation',
      name: 'findJobs (outline)',
      icon: TablerIcons.briefcase,
    ),
    (
      group: 'Navigation',
      name: 'findJobs (filled)',
      icon: TablerIcons.briefcase_filled,
    ),
    (group: 'Navigation', name: 'applied', icon: TablerIcons.checklist),
    (
      group: 'Navigation',
      name: 'messages (outline)',
      icon: TablerIcons.message_circle,
    ),
    (
      group: 'Navigation',
      name: 'messages (filled)',
      icon: TablerIcons.message_circle_filled,
    ),
    (group: 'Navigation', name: 'profile (outline)', icon: TablerIcons.user),
    (
      group: 'Navigation',
      name: 'profile (filled)',
      icon: TablerIcons.user_filled,
    ),
    (group: 'Domain', name: 'verified', icon: verified),
    (group: 'Domain', name: 'licence', icon: licence),
    (group: 'Domain', name: 'trade', icon: trade),
    (group: 'Domain', name: 'builder', icon: builder),
    (group: 'Domain', name: 'location', icon: location),
    (group: 'Domain', name: 'locationFilled', icon: locationFilled),
    (group: 'Domain', name: 'budget', icon: budget),
    (group: 'Domain', name: 'calendar', icon: calendar),
    (group: 'Domain', name: 'clock', icon: clock),
    (group: 'Domain', name: 'insurance', icon: insurance),
    (group: 'Domain', name: 'abn', icon: abn),
    (group: 'Domain', name: 'document', icon: document),
    (group: 'Actions', name: 'search', icon: search),
    (group: 'Actions', name: 'filter', icon: filter),
    (group: 'Actions', name: 'sort', icon: sort),
    (group: 'Actions', name: 'post', icon: post),
    (group: 'Actions', name: 'addCircle', icon: addCircle),
    (group: 'Actions', name: 'addBox', icon: addBox),
    (group: 'Actions', name: 'edit', icon: edit),
    (group: 'Actions', name: 'editProfile', icon: editProfile),
    (group: 'Actions', name: 'delete', icon: delete),
    (group: 'Actions', name: 'share', icon: share),
    (group: 'Actions', name: 'save', icon: save),
    (group: 'Actions', name: 'saved', icon: saved),
    (group: 'Actions', name: 'close', icon: close),
    (group: 'Actions', name: 'closeCircle', icon: closeCircle),
    (group: 'Actions', name: 'back', icon: back),
    (group: 'Actions', name: 'forward', icon: forward),
    (group: 'Actions', name: 'expand', icon: expand),
    (group: 'Actions', name: 'collapse', icon: collapse),
    (group: 'Actions', name: 'more', icon: more),
    (group: 'Actions', name: 'refresh', icon: refresh),
    (group: 'Actions', name: 'send', icon: send),
    (group: 'Status', name: 'success', icon: success),
    (group: 'Status', name: 'error', icon: error),
    (group: 'Status', name: 'warning', icon: warning),
    (group: 'Status', name: 'info', icon: info),
    (group: 'Status', name: 'pending', icon: pending),
    (group: 'Auth', name: 'email', icon: email),
    (group: 'Auth', name: 'emailAlert', icon: emailAlert),
    (group: 'Auth', name: 'password', icon: password),
    (group: 'Auth', name: 'visible', icon: visible),
    (group: 'Auth', name: 'hidden', icon: hidden),
    (group: 'Auth', name: 'google', icon: google),
    (group: 'Auth', name: 'apple', icon: apple),
    (group: 'Auth', name: 'logout', icon: logout),
    (group: 'Settings', name: 'settings', icon: settings),
    (group: 'Settings', name: 'notifications', icon: notifications),
    (group: 'Settings', name: 'help', icon: help),
    (group: 'Settings', name: 'legal', icon: legal),
    (group: 'Settings', name: 'privacy', icon: privacy),
    (group: 'Communication', name: 'phone', icon: phone),
    (group: 'Communication', name: 'chat', icon: chat),
    (group: 'Misc', name: 'rating', icon: rating),
    (group: 'Misc', name: 'ratingFilled', icon: ratingFilled),
    (group: 'Misc', name: 'favorite', icon: favorite),
    (group: 'Misc', name: 'favoriteFilled', icon: favoriteFilled),
    (group: 'Misc', name: 'image', icon: image),
    (group: 'Misc', name: 'imageError', icon: imageError),
    (group: 'Misc', name: 'camera', icon: camera),
    (group: 'Misc', name: 'card', icon: card),
    (group: 'Misc', name: 'receipt', icon: receipt),
    (group: 'Misc', name: 'award', icon: award),
    (group: 'Misc', name: 'archive', icon: archive),
    (group: 'Misc', name: 'quote', icon: quote),
    (group: 'Misc', name: 'map', icon: map),
    (group: 'Misc', name: 'gridView', icon: gridView),
    (group: 'Misc', name: 'flash', icon: flash),
    (group: 'Misc', name: 'size', icon: size),
    (group: 'Misc', name: 'wifi', icon: wifi),
    (group: 'Misc', name: 'lightMode', icon: lightMode),
    (group: 'Misc', name: 'darkMode', icon: darkMode),
  ];
}
