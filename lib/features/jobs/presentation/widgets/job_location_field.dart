import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/widgets/inputs/j_place_field.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../../profile/presentation/widgets/profile_location_field.dart'
    show kPlacesEnabled;

/// LOCATION row on /jobs/create.
///
/// When [kPlacesEnabled] is true (MAPTILER_API_KEY configured in env, or
/// `--dart-define=PLACES_ENABLED=true` forcing it on), renders a single
/// [JPlaceField] bound to `name: 'place'`. The parent _post handler splits
/// the resulting [JPlaceResult] into suburb / state / postcode / lat / lng /
/// formatted_address / place_id.
///
/// When disabled (no MapTiler key + no force-on override), renders a 3-field
/// SUBURB / STATE / POSTCODE row. This is **wider** than the previous
/// 2-field row — adding the postcode field is the silent-bug fix called out
/// in `docs/LOCATION_PICKER_AUDIT.md` §2.1: the old form had no postcode
/// input so every legacy job row landed in the DB with an empty postcode.
class JobLocationField extends StatelessWidget {
  const JobLocationField({super.key});

  @override
  Widget build(BuildContext context) {
    return kPlacesEnabled ? const _PlaceBranch() : const _LegacyBranch();
  }
}

class _PlaceBranch extends StatelessWidget {
  const _PlaceBranch();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('LOCATION'),
        Gap(8.h),
        JPlaceField(
          name: 'place',
          label: 'LOCATION',
          validator: (value) =>
              value == null ? 'Pick a suburb to continue.' : null,
        ),
      ],
    );
  }
}

class _LegacyBranch extends StatelessWidget {
  const _LegacyBranch();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('LOCATION'),
        Gap(8.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: JTextField(
                name: 'suburb',
                hint: 'e.g. Parramatta',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: FormBuilderValidators.required(
                  errorText: 'Required.',
                ),
              ),
            ),
            Gap(10.w),
            Expanded(
              flex: 2,
              child: JTextField(
                name: 'state',
                hint: 'NSW',
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                validator: FormBuilderValidators.required(
                  errorText: 'Required.',
                ),
              ),
            ),
            Gap(10.w),
            Expanded(
              flex: 3,
              child: JTextField(
                name: 'postcode',
                hint: '2150',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: FormBuilderValidators.match(
                  RegExp(r'^\d{4}$'),
                  errorText: '4 digits.',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

