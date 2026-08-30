import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import 'j_basemap.dart';

/// Licence credit for the tiles [basemap] is actually serving.
///
/// Not decoration — both licences make it mandatory. OpenStreetMap's ODbL
/// requires "© OpenStreetMap contributors" wherever its data is shown, and
/// MapTiler's terms require crediting them too whenever the tiles come from
/// their servers. Because [JBasemap] silently degrades to OSM on a build with
/// no key, the credit has to be derived from what got rendered rather than
/// from what was asked for — hence [JBasemap.servedByMapTiler] rather than a
/// hard-coded list.
class JBasemapAttribution extends StatelessWidget {
  const JBasemapAttribution({
    super.key,
    required this.basemap,
    this.bottomPadding = 0,
  });

  final JBasemap basemap;

  /// Lifts the credit above a bottom card carousel. Without it the expanded
  /// credits panel opens underneath the cards and can't be read or tapped.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: RichAttributionWidget(
        alignment: AttributionAlignment.bottomLeft,
        attributions: [
          if (basemap.servedByMapTiler)
            TextSourceAttribution(
              'MapTiler',
              onTap: () =>
                  launchUrl(Uri.parse('https://www.maptiler.com/copyright/')),
            ),
          TextSourceAttribution(
            'OpenStreetMap contributors',
            onTap: () =>
                launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
          ),
        ],
      ),
    );
  }
}
