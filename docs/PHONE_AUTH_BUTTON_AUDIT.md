# Phone Auth Page — Button & Navigation Usability Audit

**File:** `lib/features/auth/presentation/pages/phone_auth_page.dart`
**Triggered by:** Runtime `GoError: There is nothing to pop` crash logged on Android.

---

## Issues

### 1. CRASH — Back button on step 0 calls `context.pop()` with nothing to pop
**Severity: Critical**
**Line:** 111

```dart
// step 0 back button
onPressed: () => context.pop(),
```

`/phone-auth` is a top-level GoRouter route. When the user lands on it directly (e.g. from a button on `/login`) GoRouter pushes it as a new full-screen page — so `context.canPop()` is `true` and `pop()` works fine. **But** if the router redirects to `/phone-auth` (e.g. during initial auth flow), there is no previous page on the stack, so `context.pop()` throws `GoError: There is nothing to pop` and cascades 4× before the frame is discarded.

**Fix:** Guard with `context.canPop()` and fall back to `context.go('/login')`:

```dart
onPressed: () {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/login');
  }
},
```

---

### 2. HIGH — VERIFY button active and silently no-ops with fewer than 6 OTP digits
**Severity: High**
**Lines:** 343–349

```dart
AppButton(
  label: authState.isLoading ? 'Verifying...' : 'VERIFY',
  isLoading: authState.isLoading,
  onPressed: authState.isLoading
      ? null
      : () => onOtpComplete(otpController.text),  // silently returns if < 6 chars
),
```

`_submitOtp` early-returns when `token.length < 6`, but the button gives no feedback — it looks interactive, the user taps it, nothing happens. There's no error message and no disabled state.

**Fix:** Disable the button when the OTP field has fewer than 6 digits. Because `_OtpStep` is a `StatelessWidget`, the cleanest approach is to pass `otpController` down and listen to its value with a `ValueListenableBuilder`, or promote the 6-digit "complete" flag to the parent state.

---

### 3. HIGH — Pinput stays interactive during async OTP verification
**Severity: High**
**Lines:** 320–329, 343–349

When the VERIFY button is tapped (or `onCompleted` fires), `_submitOtp` is `async`. During the await, `authState.isLoading` becomes `true` and the VERIFY button disables, but `Pinput` itself remains fully editable. The user can delete and re-type digits mid-flight, causing the OTP controller value to diverge from the token being verified.

**Fix:** Pass `authState.isLoading` to `_OtpStep` and set `Pinput.enabled = !authState.isLoading`.

---

### 4. MEDIUM — Phone field accepts any non-empty string (no format validation)
**Severity: Medium**
**Lines:** 57–60

```dart
Future<void> _submitPhone() async {
  final phone = _phoneController.text.trim();
  if (phone.isEmpty) return;   // only guard is non-empty
  ...
}
```

A single character (e.g. `"a"`) passes through to the Supabase OTP call. The call will fail, but the error is caught and shown as a `StatusBanner` only after a network round-trip. This wastes latency and degrades UX.

**Fix:** Add a local regex check before the async call:

```dart
final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
if (!phoneRegex.hasMatch(phone)) {
  // show inline error without hitting Supabase
  return;
}
```

A proper Australian-format hint (`+61 4xx xxx xxx`) is already shown in `hintText` — validation should match it.

---

### 5. MEDIUM — Resend code link has no disabled visual feedback and an undersized tap target
**Severity: Medium**
**Lines:** 354–366

```dart
GestureDetector(
  onTap: resendCountdown > 0 ? null : onResend,
  child: Text(
    resendCountdown > 0 ? 'Resend in ${resendCountdown}s' : 'Resend code',
    ...
  ),
),
```

Two problems:
- `GestureDetector` with `onTap: null` provides zero visual disabled state — the text stays the same color and shows no indication it is inactive.
- The raw `Text` widget has no padding, making the tap target well below the 48×48 dp minimum.

**Fix:** Replace with a `TextButton` or wrap in `Padding` + `InkWell` with `borderRadius`. Use `Opacity(opacity: 0.4)` or a dimmer color (currently `c.text3`) for the disabled state — which is already half done with `color: resendCountdown > 0 ? c.text3 : c.action`. Adding `Opacity` on the wrapper makes the intent clearer than a color-only change.

---

### 6. LOW — `phone` snapshot passed to `_OtpStep` at build time
**Severity: Low**
**Line:** 132

```dart
_OtpStep(
  phone: _phoneController.text,   // captured at build time
  ...
)
```

If `_phoneController.text` were ever modified after `_step` transitions to 1, the displayed phone number on the OTP step would be stale. In current code this can't happen because the phone field is on step 0 and the keyboard is not shown on step 1, but it is a latent correctness risk.

**Fix:** Promote the submitted phone to a `String _submittedPhone = ''` field set in `_submitPhone()`, and pass that to `_OtpStep` instead.

---

## Fix priority

| # | Issue | Action |
|---|-------|--------|
| 1 | `context.pop()` crash | **Fix now** — production crash |
| 2 | VERIFY silently no-ops | Fix in same pass |
| 3 | Pinput editable during loading | Fix in same pass |
| 4 | No phone format validation | Fix in same pass |
| 5 | Resend tap target / disabled state | Fix in same pass |
| 6 | Stale phone snapshot | Nice-to-have cleanup |
