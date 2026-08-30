part of 'job_create_page.dart';

// Pure helpers for [JobCreatePage], split into a `part` so the page file
// stays under the 500 LOC ceiling and inside the 400 LOC target. None of
// these touch widget state — they take everything they need as arguments,
// which is why they lift cleanly out of the State class.

void _showError(
  ScaffoldMessengerState messenger,
  JColors c,
  TextTheme tt,
  String message,
) {
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            AppIcons.urgent,
            size: AppIconSize.md.r,
            color: Colors.white, // intentional: white-on-error
          ),
          Gap(10.w),
          Expanded(
            child: Text(
              message,
              style: tt.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white, // intentional: white-on-error
              ),
            ),
          ),
        ],
      ),
      backgroundColor: c.urgent,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Maps the validated form into a domain [Job]. `id`/timestamps are
/// placeholders — `JobModel.toJson` drops them so the DB generates them.
Job _buildJob(String builderId, Map<String, dynamic> values) {
  final now = DateTime.now();
  final rate = double.tryParse('${values['rate'] ?? ''}');
  final pricingType =
      values['pricingMode'] as PricingType? ?? PricingType.builderSet;
  final pricingUnit =
      values['pricingUnit'] as PricingUnit? ?? PricingUnit.hourly;

  // Location resolves two ways: the MapTiler picker emits a single
  // JPlaceResult under 'place'; the legacy fallback emits suburb / state /
  // postcode as separate fields.
  var suburb = '';
  var state = '';
  var postcode = '';
  double? latitude;
  double? longitude;
  String? formattedAddress;
  String? placeId;
  final place = values['place'];
  if (place is JPlaceResult) {
    suburb = place.suburb;
    state = place.state;
    postcode = place.postcode;
    latitude = place.latitude;
    longitude = place.longitude;
    formattedAddress = place.formattedAddress;
    placeId = place.placeId;
  } else {
    suburb = (values['suburb'] as String? ?? '').trim();
    state = (values['state'] as String? ?? '').trim().toUpperCase();
    postcode = (values['postcode'] as String? ?? '').trim();
  }

  return Job(
    id: '',
    builderId: builderId,
    title: (values['title'] as String).trim(),
    description: (values['description'] as String).trim(),
    tradeTypeRequired: values['trade'] as String,
    suburb: suburb,
    state: state,
    postcode: postcode,
    status: JobStatus.open,
    createdAt: now,
    updatedAt: now,
    // budget_amount only when the builder named a price; null for
    // request_quote (matches the jobs_budget_amount_when_set CHECK).
    budgetAmount: pricingType == PricingType.builderSet ? rate : null,
    pricingType: pricingType,
    pricingUnit: pricingUnit,
    urgency: (values['urgent'] as bool? ?? false)
        ? JobUrgency.urgent
        : JobUrgency.standard,
    latitude: latitude,
    longitude: longitude,
    formattedAddress: formattedAddress,
    placeId: placeId,
  );
}

/// On a failed submit, scrolls the first invalid field into view so the
/// builder sees what's blocking POST instead of just feeling a haptic with
/// the error off-screen. Order mirrors the visual top-to-bottom layout.
void _scrollToFirstError(FormBuilderState? formState) {
  if (formState == null) return;
  const order = [
    'title',
    'trade',
    'description',
    'place',
    'suburb',
    'state',
    'postcode',
    'rate',
  ];
  for (final name in order) {
    final field = formState.fields[name];
    if (field != null && field.hasError) {
      Scrollable.ensureVisible(
        field.context,
        alignment: 0.1,
        duration: AppMotion.medium,
        curve: AppMotion.standard,
      );
      return;
    }
  }
}
