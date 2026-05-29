part of 'home_page.dart';

// GENERATED-SPLIT: part of home_page.dart (file-size budget). No behaviour change.

// ── Map View ──────────────────────────────────────────────────────────────────

// Selectable basemap. All four sources are free + key-less and properly
// attributed by RichAttributionWidget below. Add a new style by extending this
// enum — the picker sheet, persistence, and tile layer pick it up automatically.
enum _MapStyle {
  dark(
    label: 'DARK',
    description: 'Brand-aligned night view',
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    subdomains: ['a', 'b', 'c', 'd'],
    source: _TileSource.carto,
  ),
  light(
    label: 'LIGHT',
    description: 'Clean daytime view',
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    subdomains: ['a', 'b', 'c', 'd'],
    source: _TileSource.carto,
  ),
  voyager(
    label: 'VOYAGER',
    description: 'Colourful — pins pop',
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
    subdomains: ['a', 'b', 'c', 'd'],
    source: _TileSource.carto,
  ),
  standard(
    label: 'STANDARD',
    description: 'Classic OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    subdomains: <String>[],
    source: _TileSource.osm,
  );

  const _MapStyle({
    required this.label,
    required this.description,
    required this.urlTemplate,
    required this.subdomains,
    required this.source,
  });

  final String label;
  final String description;
  final String urlTemplate;
  final List<String> subdomains;
  final _TileSource source;

  // Pin colour suggestion — keep the brand orange on dark/voyager (high
  // contrast); on the light style use a slightly darker fill so the pin still
  // reads against a near-white background without changing the action token.
  bool get prefersDarkText => this == _MapStyle.light;
}

enum _TileSource { carto, osm }

const String _kMapStylePrefsKey = 'home.map_style';

class _MapView extends StatefulWidget {
  const _MapView({
    required this.jobs,
    required this.placeLabel,
    required this.onJobTap,
  });

  final List<Job> jobs;
  // Suburb/state string used for the "NEAR <place> • 5 KM" radius chip.
  final String placeLabel;
  final ValueChanged<Job> onJobTap;

  @override
  State<_MapView> createState() => _MapViewState();
}

// Search radius rendered as both a translucent circle on the map and a chip
// in the top-left. Tweak in one place if product wants a different default.
const double _kSearchRadiusKm = 5.0;

// Outcome of the current location request — drives the in-map banner UX.
enum _LocationStatus {
  idle,
  requesting,
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  error,
}

class _MapViewState extends State<_MapView> {
  static const _sydney = LatLng(-33.8688, 151.2093);

  final MapController _controller = MapController();
  _MapStyle _style = _MapStyle.voyager;
  LatLng? _userLocation;
  _LocationStatus _locationStatus = _LocationStatus.idle;

  @override
  void initState() {
    super.initState();
    _loadStyle();
    // Defer to post-frame so the rationale dialog doesn't fight the map's
    // first render. Permission ask happens on entry to the map view — that
    // context is the strongest signal the user wants location used.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initLocation();
    });
  }

  Future<void> _loadStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMapStylePrefsKey);
    if (raw == null || !mounted) return;
    final found = _MapStyle.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => _MapStyle.voyager,
    );
    if (found != _style) setState(() => _style = found);
  }

  Future<void> _setStyle(_MapStyle next) async {
    setState(() => _style = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMapStylePrefsKey, next.name);
  }

  // Full location request lifecycle:
  //   1. Service enabled? (device GPS toggle)
  //   2. Permission state — if denied, show rationale BEFORE the native prompt
  //   3. Fetch position (10s budget, medium accuracy — city-block is enough)
  //   4. Centre the map on success; surface banner on every failure mode
  Future<void> _initLocation() async {
    setState(() => _locationStatus = _LocationStatus.requesting);

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      setState(() => _locationStatus = _LocationStatus.serviceDisabled);
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      if (!mounted) return;
      final agreed = await _showRationaleDialog();
      if (!mounted) return;
      if (!agreed) {
        setState(() => _locationStatus = _LocationStatus.denied);
        return;
      }
      permission = await Geolocator.requestPermission();
    }

    if (!mounted) return;

    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationStatus = _LocationStatus.deniedForever);
      return;
    }
    if (permission == LocationPermission.denied) {
      setState(() => _locationStatus = _LocationStatus.denied);
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userLocation = latLng;
        _locationStatus = _LocationStatus.granted;
      });
      // Zoom 12 matches the initial framing so the 5 km radius circle fits
      // comfortably in view after the camera moves to the user.
      _controller.move(latLng, 12);
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationStatus = _LocationStatus.error);
    }
  }

  // Custom rationale — shown ONCE per request, before the OS prompt. Gives
  // the user a Jobdun-branded explanation instead of the bare native dialog
  // that says nothing about why we want it.
  Future<bool> _showRationaleDialog() async {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2.r)),
        title: Text(
          'SHOW JOBS NEAR YOU',
          style: tt.headlineSmall!.copyWith(color: c.text1, letterSpacing: 0.5),
        ),
        content: Text(
          'Jobdun needs your location to centre the map on you and surface '
          'jobs nearby. We only use it while you have the map open — never in '
          'the background.',
          style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'NOT NOW',
              style: tt.labelLarge!.copyWith(
                color: c.text2,
                letterSpacing: 0.5,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'CONTINUE',
              style: tt.labelLarge!.copyWith(
                color: c.action,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openSettings() async {
    await Geolocator.openAppSettings();
  }

  // Effective centre for the search radius + sample-pin spread: actual user
  // GPS if granted, otherwise the Sydney default. Stays a LatLng (not nullable)
  // so the CircleLayer + sample generator always have something to anchor on.
  LatLng get _radiusCenter => _userLocation ?? _sydney;

  // Real jobs win whenever they're available; otherwise we synthesize a
  // small set of clickable pins inside the radius so the map view always
  // demos end-to-end (pin → tap → detail page).
  List<Job> get _effectiveJobs =>
      widget.jobs.isNotEmpty ? widget.jobs : _sampleJobsAround(_radiusCenter);

  List<Marker> _buildMarkers(Color pinColor, Color pinBorder) {
    return [
      for (final job in _effectiveJobs)
        if (job.latitude != null && job.longitude != null)
          Marker(
            point: LatLng(job.latitude!, job.longitude!),
            width: 40,
            height: 40,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onJobTap(job),
              child: Container(
                decoration: BoxDecoration(
                  color: pinColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: pinBorder, width: 2),
                ),
                child: const Icon(
                  AppIcons.locationFilled,
                  size: 20,
                  color: Colors.white, // intentional: white-on-action
                ),
              ),
            ),
          ),
      // User position — solid white dot with brand-orange ring. Clearly
      // distinct from the orange job pins above so the user can tell
      // "where I am" from "what's around me" at a glance.
      if (_userLocation != null)
        Marker(
          point: _userLocation!,
          width: 22,
          height: 22,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, // intentional: white-on-action
              shape: BoxShape.circle,
              border: Border.all(color: pinColor, width: 3),
            ),
          ),
        ),
    ];
  }

  List<TextSourceAttribution> _attributionsFor(_MapStyle style) {
    return [
      TextSourceAttribution(
        'OpenStreetMap contributors',
        onTap: () =>
            launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
      ),
      if (style.source == _TileSource.carto)
        TextSourceAttribution(
          'CARTO',
          onTap: () => launchUrl(Uri.parse('https://carto.com/attribution')),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: const MapOptions(
            initialCenter: _sydney,
            // Zoom 12 frames the 5 km search radius cleanly without clipping
            // the outer ring on a typical phone viewport.
            initialZoom: 12,
            minZoom: 3,
            maxZoom: 18,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              // Keyed so flutter_map drops the old tile cache when the
              // template changes — otherwise mixed-style tiles flash during
              // the swap.
              key: ValueKey<_MapStyle>(_style),
              urlTemplate: _style.urlTemplate,
              subdomains: _style.subdomains,
              retinaMode: RetinaMode.isHighDensity(context),
              userAgentPackageName: 'com.example.jobdun',
            ),
            // Search-radius circle drawn under the markers so pins sit on top.
            // Uses meters for the radius so it scales with the zoom level —
            // that's the visual cue the user actually reads as "your area".
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _radiusCenter,
                  radius: _kSearchRadiusKm * 1000,
                  useRadiusInMeter: true,
                  color: c.action.withValues(alpha: 0.10),
                  borderColor: c.action,
                  borderStrokeWidth: 1.5,
                ),
              ],
            ),
            MarkerLayer(markers: _buildMarkers(c.action, c.surface)),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: _attributionsFor(_style),
            ),
          ],
        ),
        // Top-left radius chip — tells the user exactly what they're looking
        // at: the suburb name and the search radius the pins are filtered by.
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 12.h, 0, 0),
              child: _RadiusChip(
                placeLabel: widget.placeLabel,
                radiusKm: _kSearchRadiusKm,
              ),
            ),
          ),
        ),
        // Top-right floating controls. SafeArea pushes them below the status
        // bar/notch; the Column gives the style chip and recenter button a
        // consistent 8.h gap so they never overlap each other.
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 12.h, 12.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapStyleButton(
                    current: _style,
                    onTap: () async {
                      final next = await _showStyleSheet(context, _style);
                      if (next != null && next != _style) {
                        await _setStyle(next);
                      }
                    },
                  ),
                  Gap(8.h),
                  _RecenterButton(
                    isLoading: _locationStatus == _LocationStatus.requesting,
                    hasLocation: _userLocation != null,
                    onTap: () {
                      if (_userLocation != null) {
                        // Match the initial framing zoom so the radius circle
                        // stays visible after recentering.
                        _controller.move(_userLocation!, 12);
                      } else {
                        _initLocation();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_locationStatus == _LocationStatus.denied ||
            _locationStatus == _LocationStatus.deniedForever ||
            _locationStatus == _LocationStatus.serviceDisabled ||
            _locationStatus == _LocationStatus.error)
          Positioned(
            left: 12.w,
            right: 12.w,
            bottom: 12.h,
            child: _LocationStatusBanner(
              status: _locationStatus,
              onRetry: _initLocation,
              onOpenSettings: _openSettings,
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
