part of 'home_page.dart';

// GENERATED-SPLIT: part of home_page.dart (file-size budget). No behaviour change.

// ── Sample / fallback data ─────────────────────────────────────────────────────

class _TradieData {
  const _TradieData({
    required this.name,
    required this.trade,
    required this.suburb,
    required this.rating,
    required this.jobCount,
    required this.isVerified,
    required this.isAvailable,
    required this.distanceKm,
    required this.initials,
  });

  final String name;
  final String trade;
  final String suburb;
  final double rating;
  final int jobCount;
  final bool isVerified;
  final bool isAvailable;
  final double distanceKm;
  final String initials;
}

class _MockJob {
  const _MockJob({
    required this.title,
    required this.description,
    required this.rate,
    required this.startDate,
    required this.distanceKm,
    required this.isUrgent,
  });

  final String title;
  final String description;
  final String rate;
  final String startDate;
  final double distanceKm;
  final bool isUrgent;
}

const _tradies = [
  _TradieData(
    name: 'Marcus Webb',
    trade: 'Electrician',
    suburb: 'Parramatta',
    rating: 4.9,
    jobCount: 142,
    isVerified: true,
    isAvailable: true,
    distanceKm: 3.2,
    initials: 'MW',
  ),
  _TradieData(
    name: "Sarah O'Brien",
    trade: 'Plumber',
    suburb: 'Bondi',
    rating: 4.7,
    jobCount: 89,
    isVerified: true,
    isAvailable: true,
    distanceKm: 5.1,
    initials: 'SO',
  ),
  _TradieData(
    name: 'Jake Kowalski',
    trade: 'Carpenter',
    suburb: 'Newtown',
    rating: 4.6,
    jobCount: 67,
    isVerified: false,
    isAvailable: false,
    distanceKm: 7.8,
    initials: 'JK',
  ),
];

const _mockJobs = [
  _MockJob(
    title: 'Install 3-phase switchboard at commercial site',
    description:
        'Install a 3-phase switchboard at our commercial fit-out in Surry Hills. Conduit run, panel installation, and termination.',
    rate: r'$85/hr',
    startDate: 'Tomorrow',
    distanceKm: 2.4,
    isUrgent: true,
  ),
  _MockJob(
    title: 'Frame internal walls for home renovation',
    description:
        'Steel stud framing approximately 120 LM for a full home renovation in Newtown. Drawings available on site.',
    rate: r'$45/hr',
    startDate: '12 May',
    distanceKm: 4.8,
    isUrgent: false,
  ),
  _MockJob(
    title: 'Concrete footings for deck extension',
    description:
        '8 × 300mm dia pad footings, 600mm deep. Reinforcement to be supplied by contractor.',
    rate: r'$75/hr',
    startDate: '14 May',
    distanceKm: 9.1,
    isUrgent: false,
  ),
];

// Demo job pins generated around a given centre — used by the map view when
// there is no real Supabase data with location yet. Pins are offset within
// roughly the 5 KM search radius so the user sees the radius circle "filled"
// with jobs wherever they happen to be testing (not just in Sydney).
//
// Each template is a const description of the job; coords are computed at
// runtime by adding the dLat / dLng offset to [center]. Distances assume
// ~111 km per degree latitude / longitude near the equator — close enough
// for tradesperson-scale radii (within a couple percent at -33° lat).
class _SampleJobTemplate {
  const _SampleJobTemplate({
    required this.idSuffix,
    required this.title,
    required this.description,
    required this.trade,
    required this.urgency,
    required this.budgetMin,
    this.budgetMax,
    required this.daysOut,
    required this.dLat,
    required this.dLng,
  });

  final String idSuffix;
  final String title;
  final String description;
  final String trade;
  final JobUrgency urgency;
  final double budgetMin;
  final double? budgetMax;
  final int daysOut;
  final double dLat;
  final double dLng;
}

const _sampleJobTemplates = <_SampleJobTemplate>[
  _SampleJobTemplate(
    idSuffix: 'switchboard',
    title: 'Install 3-phase switchboard',
    description:
        'Commercial fit-out. Conduit run, panel installation, and termination on a 3-phase board.',
    trade: 'Electrician',
    urgency: JobUrgency.urgent,
    budgetMin: 85,
    daysOut: 1,
    dLat: 0.018,
    dLng: 0.022,
  ),
  _SampleJobTemplate(
    idSuffix: 'framing',
    title: 'Frame internal walls — home reno',
    description:
        'Steel-stud framing ~120 LM for a full home renovation. Drawings on site.',
    trade: 'Carpenter',
    urgency: JobUrgency.standard,
    budgetMin: 45,
    daysOut: 3,
    dLat: -0.022,
    dLng: 0.012,
  ),
  _SampleJobTemplate(
    idSuffix: 'footings',
    title: 'Concrete footings for deck extension',
    description:
        '8 × 300mm dia pad footings, 600mm deep. Reinforcement supplied by contractor.',
    trade: 'Concreter',
    urgency: JobUrgency.standard,
    budgetMin: 75,
    daysOut: 5,
    dLat: 0.008,
    dLng: -0.025,
  ),
  _SampleJobTemplate(
    idSuffix: 'plumbing',
    title: 'Bathroom rough-in — townhouse',
    description:
        'Hot/cold + waste rough-in across two new bathrooms. PEX-A throughout.',
    trade: 'Plumber',
    urgency: JobUrgency.standard,
    budgetMin: 95,
    daysOut: 2,
    dLat: -0.014,
    dLng: -0.018,
  ),
  _SampleJobTemplate(
    idSuffix: 'roofing',
    title: 'Roof tile repair — storm damage',
    description:
        'Storm-damaged terracotta tiles. Approx 40 tiles to replace + flashing repair.',
    trade: 'Roofer',
    urgency: JobUrgency.urgent,
    budgetMin: 65,
    budgetMax: 85,
    daysOut: 1,
    dLat: 0.025,
    dLng: -0.005,
  ),
];

List<Job> _sampleJobsAround(LatLng center) {
  final now = DateTime.now();
  return [
    for (final t in _sampleJobTemplates)
      Job(
        id: 'sample-${t.idSuffix}',
        builderId: 'sample-builder',
        title: t.title,
        description: t.description,
        tradeTypeRequired: t.trade,
        // No real reverse-geocoding yet — the radius chip carries the place
        // label for the user. Suburb here is a generic placeholder shown
        // on the detail screen.
        suburb: 'Nearby',
        state: 'NSW',
        postcode: '',
        status: JobStatus.open,
        urgency: t.urgency,
        budgetMin: t.budgetMin,
        budgetMax: t.budgetMax,
        budgetType: BudgetType.hourly,
        startDate: now.add(Duration(days: t.daysOut)),
        createdAt: now,
        updatedAt: now,
        latitude: center.latitude + t.dLat,
        longitude: center.longitude + t.dLng,
      ),
  ];
}
