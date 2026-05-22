import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../../services/places_service.dart';
import '../../services/places_service_provider.dart';
import '../../theme/app_icons.dart';
import 'j_place_field_dropdown.dart';

/// AU-restricted suburb/address picker, drop-in alongside [JTextField] inside
/// any `FormBuilder` form.
///
/// Renders five states (resting / focused+dropdown / loading / selected /
/// error) on the existing Aggressive Flat token set — no new design vocabulary.
/// Backed by [placesServiceProvider] (MapTiler today, swappable). One value
/// participates in the form: a [JPlaceResult]. Pages split that into the
/// hidden suburb / state / postcode / lat / lng fields the existing save
/// path expects.
///
/// Behaviour:
/// - 250 ms debounce; no request fires before 3 chars typed.
/// - "Use my current location" chip reverse-geocodes the device position.
///   Requires location permission — falls back to a "Tap to enable" CTA
///   when denied.
/// - Network / config failures throw [PlacesException], which renders as an
///   inline error banner under the field. The page is responsible for the
///   "Edit manually" toggle (legacy 3-field fallback).
class JPlaceField extends ConsumerStatefulWidget {
  const JPlaceField({
    super.key,
    required this.name,
    required this.label,
    this.initialValue,
    this.hint = 'Search suburb, postcode or address',
    this.validator,
    this.enabled = true,
    this.onChanged,
  });

  final String name;
  final String label;
  final JPlaceResult? initialValue;
  final String? hint;
  final String? Function(JPlaceResult?)? validator;
  final bool enabled;
  final ValueChanged<JPlaceResult?>? onChanged;

  @override
  ConsumerState<JPlaceField> createState() => _JPlaceFieldState();
}

class _JPlaceFieldState extends ConsumerState<JPlaceField> {
  static const _minQueryLength = 3;
  static const _debounce = Duration(milliseconds: 250);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounceTimer;
  bool _focused = false;
  bool _loadingSuggestions = false;
  bool _resolvingCurrentLocation = false;
  List<JPlaceResult> _suggestions = const [];
  PlacesException? _error;
  JPlaceResult? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    if (_selected != null) {
      _controller.text = _selected!.formattedAddress;
    }
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  void _onTextChanged(String value, FormFieldState<JPlaceResult> field) {
    if (_selected != null) {
      _selected = null;
      field.didChange(null);
      widget.onChanged?.call(null);
    }
    _debounceTimer?.cancel();
    final query = value.trim();
    if (query.length < _minQueryLength) {
      setState(() {
        _suggestions = const [];
        _loadingSuggestions = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loadingSuggestions = true;
      _error = null;
    });
    _debounceTimer = Timer(_debounce, () => unawaited(_runQuery(query)));
  }

  Future<void> _runQuery(String query) async {
    final service = ref.read(placesServiceProvider);
    try {
      final results = await service.autocomplete(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _loadingSuggestions = false;
        _error = results.isEmpty ? const PlacesNoResults() : null;
      });
    } on PlacesException catch (error) {
      if (!mounted) return;
      setState(() {
        _suggestions = const [];
        _loadingSuggestions = false;
        _error = error;
      });
    }
  }

  void _select(JPlaceResult result, FormFieldState<JPlaceResult> field) {
    _debounceTimer?.cancel();
    _controller.text = result.formattedAddress;
    setState(() {
      _selected = result;
      _suggestions = const [];
      _loadingSuggestions = false;
      _error = null;
    });
    field.didChange(result);
    widget.onChanged?.call(result);
    _focusNode.unfocus();
  }

  void _clear(FormFieldState<JPlaceResult> field) {
    _debounceTimer?.cancel();
    _controller.clear();
    setState(() {
      _selected = null;
      _suggestions = const [];
      _loadingSuggestions = false;
      _error = null;
    });
    field.didChange(null);
    widget.onChanged?.call(null);
  }

  Future<void> _useCurrentLocation(FormFieldState<JPlaceResult> field) async {
    if (_resolvingCurrentLocation) return;
    setState(() {
      _resolvingCurrentLocation = true;
      _error = null;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _resolvingCurrentLocation = false;
          _error = const PlacesNetworkError(
            'Location permission denied. Type your suburb instead.',
          );
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final result = await ref
          .read(placesServiceProvider)
          .reverseGeocode(LatLng(position.latitude, position.longitude));
      if (!mounted) return;
      setState(() => _resolvingCurrentLocation = false);
      if (result == null) {
        setState(() => _error = const PlacesNoResults());
        return;
      }
      _select(result, field);
    } on PlacesException catch (error) {
      if (!mounted) return;
      setState(() {
        _resolvingCurrentLocation = false;
        _error = error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolvingCurrentLocation = false;
        _error = const PlacesNetworkError("Couldn't read your location.");
      });
    }
  }

  bool get _hasDropdown =>
      _focused &&
      (_loadingSuggestions ||
          _suggestions.isNotEmpty ||
          _error is PlacesNoResults);

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<JPlaceResult>(
      name: widget.name,
      initialValue: widget.initialValue,
      validator: widget.validator,
      enabled: widget.enabled,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (field) {
        final c = context.c;
        final tt = Theme.of(context).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: tt.labelMedium!.copyWith(
                color: widget.enabled ? c.text2 : c.text3,
              ),
            ),
            Gap(8.h),
            _JPlaceInputBox(
              controller: _controller,
              focusNode: _focusNode,
              hint: widget.hint,
              enabled: widget.enabled,
              focused: _focused,
              selected: _selected != null,
              hasError: field.errorText != null,
              onChanged: (value) => _onTextChanged(value, field),
              onClear: () => _clear(field),
            ),
            if (_hasDropdown) ...[
              Gap(6.h),
              JPlaceDropdown(
                suggestions: _suggestions,
                loading: _loadingSuggestions,
                resolvingCurrentLocation: _resolvingCurrentLocation,
                noResults: _error is PlacesNoResults,
                onSelect: (r) => _select(r, field),
                onUseCurrentLocation: () => _useCurrentLocation(field),
              ),
            ],
            if (field.errorText != null) ...[
              Gap(6.h),
              Text(
                field.errorText!,
                style: tt.bodySmall!.copyWith(color: c.error),
              ),
            ] else if (_error != null && _error is! PlacesNoResults) ...[
              Gap(6.h),
              Text(
                _error!.message,
                style: tt.bodySmall!.copyWith(color: c.error),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _JPlaceInputBox extends StatelessWidget {
  const _JPlaceInputBox({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.enabled,
    required this.focused,
    required this.selected,
    required this.hasError,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? hint;
  final bool enabled;
  final bool focused;
  final bool selected;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final borderColor = hasError ? c.error : (focused ? c.action : c.border);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      style: tt.bodyLarge!.copyWith(
        color: enabled ? c.text1 : c.text3,
        fontWeight: FontWeight.w500,
      ),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: 12.w, right: 8.w),
          child: Icon(
            selected ? AppIcons.locationFilled : AppIcons.location,
            size: 18.r,
            color: selected ? c.action : c.text3,
          ),
        ),
        prefixIconConstraints: BoxConstraints(minWidth: 36.w, minHeight: 36.h),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(AppIcons.close, size: 18.r, color: c.text3),
                onPressed: onClear,
                tooltip: 'Clear',
              ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2.r),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2.r),
          borderSide: BorderSide(color: borderColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2.r),
          borderSide: BorderSide(color: c.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2.r),
          borderSide: BorderSide(color: c.error, width: 2),
        ),
      ),
    );
  }
}
