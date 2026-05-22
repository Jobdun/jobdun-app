import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';

/// Thrown by [ImageUploadService.pickCropCompress] when the picked file fails
/// a client-side guard-rail (max size, MIME allowlist). Distinct from a `null`
/// return, which still means "user cancelled mid-flow".
///
/// Catch at call sites and surface `message` in a snackbar — the copy is
/// already user-friendly. Cancellations should not be caught; they're not
/// errors and the service returns `null` for them.
class UploadGuardException implements Exception {
  const UploadGuardException(this.message);
  final String message;

  @override
  String toString() => 'UploadGuardException: $message';
}

/// Standard preset aspect ratios for Jobdun uploads. Use these instead of
/// constructing [CropAspectRatio] inline so every avatar / portfolio / logo
/// upload across the app crops to the same dimensions.
enum ImageAspect {
  /// 1:1 — avatars, company logos. Lockstep with how the UI renders them
  /// (circular avatar + square logo grid).
  square,

  /// 4:3 — portfolio tiles. Matches the portfolio strip's 88×88 thumbnail
  /// then re-uses the landscape framing on the gallery viewer.
  portfolio,

  /// No forced ratio — verification documents (licence cards, certs) come
  /// in many sizes; we let the user frame to the doc edge.
  free,
}

/// Pick → crop → compress pipeline.
///
/// One entry point for every image upload in the app. Returns `null` if the
/// user dismisses any stage so the caller can short-circuit without
/// distinguishing between "didn't pick" / "didn't crop". Returns a `File`
/// pointing at a JPEG that is cropped to the requested aspect, compressed
/// to ≤ `compressQuality`, and capped at `minWidth` pixels wide — that's
/// the size that hits Supabase storage.
///
/// Why a single service: before this lived in `lib/core/services/`, every
/// caller (avatar, portfolio, verification) reinvented `ImagePicker` config
/// inline. The result was inconsistent quality (some sites picked at 85,
/// some at 92), zero cropping, and full-resolution originals landing in
/// the `avatars` / `portfolio-images` buckets — fine for v1 but expensive
/// once usage scales. Centralising the pipeline lets us tune all three
/// surfaces in one place.
class ImageUploadService {
  const ImageUploadService._();

  /// Run the full pick → crop → compress pipeline.
  ///
  /// - [source] — gallery vs. camera (passed straight through to ImagePicker).
  /// - [aspect] — see [ImageAspect].
  /// - [maxPickerSize] — the picker's own downscale cap before crop; defaults
  ///   to 2400px so the cropper has enough headroom on phone cameras.
  /// - [minOutputWidth] — final compressed width target. 1080px is the
  ///   sweet spot for the Supabase buckets; higher costs storage, lower
  ///   shows JPEG artefacts on profile/portfolio surfaces.
  /// - [compressQuality] — JPEG quality (0–100). 80 keeps detail without
  ///   ballooning file size; bump for documents/IDs that need legibility.
  /// Hard cap on the size of the file `image_picker` returns. Anything above
  /// this throws [UploadGuardException] before crop/compress runs. 10 MB
  /// matches the largest typical iPhone HEIC and leaves headroom for raw
  /// captures; the post-compression pipeline lands at ~300–800 KB.
  static const int maxBytes = 10 * 1024 * 1024;

  /// MIME-type allowlist applied to the picker output. We accept the four
  /// formats the OS pickers actually return for camera + gallery; anything
  /// else (heic-sequence, gif, bmp, tiff) gets rejected before it eats
  /// bandwidth. Verification docs reuse this list — PDF support is a
  /// separate code path that doesn't go through ImagePicker.
  static const Set<String> allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };

  static Future<File?> pickCropCompress({
    required ImageSource source,
    required ImageAspect aspect,
    double maxPickerSize = 2400,
    int minOutputWidth = 1080,
    int compressQuality = 80,
  }) async {
    // 1. Pick
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: maxPickerSize,
      maxHeight: maxPickerSize,
    );
    if (picked == null) return null;

    // 1a. Guard-rails — extension allowlist + max size. Surfaces a typed
    // exception so the snackbar copy at the call site is friendly. We check
    // size against the raw picker output (pre-compress) so a 50 MB camera
    // RAW doesn't waste cycles in the cropper before failing.
    final ext = picked.name.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      throw UploadGuardException(
        "Photos must be JPG, PNG, WebP, or HEIC. We can't accept .$ext.",
      );
    }
    final size = await picked.length();
    if (size > maxBytes) {
      final mb = (size / (1024 * 1024)).toStringAsFixed(1);
      throw UploadGuardException(
        'Photo is $mb MB — please pick one under '
        '${(maxBytes / (1024 * 1024)).toStringAsFixed(0)} MB.',
      );
    }

    // 2. Crop. The image_cropper package shells out to native crop UIs on
    // each platform; the colours here paint that native UI in the Jobdun
    // palette so the hop out of the app feels seamless.
    final cropped = await _runCropper(picked.path, aspect);
    if (cropped == null) return null;

    // 3. Compress to JPEG. Write next to the cropped temp file — image_cropper
    // already drops CroppedFile in the OS temp dir, so we reuse that location
    // and avoid taking a path_provider dependency just for getTemporaryDirectory.
    final outPath = '${cropped.path}_c.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      cropped.path,
      outPath,
      quality: compressQuality,
      minWidth: minOutputWidth,
      format: CompressFormat.jpeg,
    );
    // If compression fails for any reason (rare — usually unsupported
    // source format) fall back to the cropped file so the upload still
    // succeeds rather than silently dropping the user's pick.
    if (compressed == null) return File(cropped.path);
    return File(compressed.path);
  }

  static Future<CroppedFile?> _runCropper(
    String sourcePath,
    ImageAspect aspect,
  ) {
    final ratio = _aspectRatio(aspect);
    final lockAspect = ratio != null;
    return ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: ratio,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'CROP',
          toolbarColor: JColors.dark.background,
          toolbarWidgetColor: JColors.dark.text1,
          backgroundColor: JColors.dark.background,
          activeControlsWidgetColor: JColors.dark.action,
          lockAspectRatio: lockAspect,
          hideBottomControls: lockAspect,
          aspectRatioPresets: _androidPresets(aspect),
        ),
        IOSUiSettings(
          title: 'CROP',
          aspectRatioLockEnabled: lockAspect,
          resetButtonHidden: lockAspect,
          rotateButtonsHidden: false,
          aspectRatioPickerButtonHidden: lockAspect,
          aspectRatioPresets: _iosPresets(aspect),
        ),
        WebUiSettings(context: _navigatorContext),
      ],
    );
  }

  static CropAspectRatio? _aspectRatio(ImageAspect aspect) {
    switch (aspect) {
      case ImageAspect.square:
        return const CropAspectRatio(ratioX: 1, ratioY: 1);
      case ImageAspect.portfolio:
        return const CropAspectRatio(ratioX: 4, ratioY: 3);
      case ImageAspect.free:
        return null;
    }
  }

  static List<CropAspectRatioPreset> _androidPresets(ImageAspect aspect) {
    switch (aspect) {
      case ImageAspect.square:
        return const [CropAspectRatioPreset.square];
      case ImageAspect.portfolio:
        return const [CropAspectRatioPreset.ratio4x3];
      case ImageAspect.free:
        return const [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio4x3,
        ];
    }
  }

  static List<CropAspectRatioPreset> _iosPresets(ImageAspect aspect) =>
      _androidPresets(aspect);

  // image_cropper requires a BuildContext for its WebUiSettings constructor
  // even though we never hit the web target in v1. Carrying a synthetic
  // context keeps the call site shape consistent across platforms — the
  // value is unused on Android/iOS where the native crop UI runs.
  static BuildContext get _navigatorContext =>
      WidgetsBinding.instance.rootElement!;
}
