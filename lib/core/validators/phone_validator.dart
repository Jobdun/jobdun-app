// Centralised phone validation + formatting for the phone-auth flow.
//
// AU-first by design (Jobdun's primary market is Australian trades) but a
// small set of supported countries — common origins for migrant tradies in
// AU construction (NZ, GB, IE, IN, PH) plus US/CA for completeness.
//
// Each country owns its own digit-only regex against the *national* number
// (after stripping the dial code). Combined with the dial code we build the
// E.164 string Supabase expects.

class Country {
  const Country({
    required this.code,
    required this.dialCode,
    required this.name,
    required this.flag,
    required this.exampleNational,
    required this.localFormatHint,
  });

  /// ISO 3166-1 alpha-2 (e.g. 'AU').
  final String code;

  /// E.164 dial code without '+' (e.g. '61').
  final String dialCode;

  /// Display name in English.
  final String name;

  /// Flag emoji — works on every modern Flutter target without an asset bundle.
  final String flag;

  /// Example national-format number shown as hint.
  final String exampleNational;

  /// Human-readable format hint (e.g. "4XX XXX XXX").
  final String localFormatHint;

  /// Builds the E.164 string Supabase wants: `+<dialCode><nationalDigits>`.
  /// Strips any non-digit from input first.
  String toE164(String nationalInput) {
    final digits = nationalInput.replaceAll(RegExp(r'\D'), '');
    return '+$dialCode$digits';
  }

  /// Returns null on valid input, or an error string for the field.
  String? validate(String nationalInput) {
    final digits = nationalInput.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Mobile number is required.';
    if (!nationalRegexFor(this).hasMatch(digits)) {
      return 'Enter a valid $name mobile (e.g. $exampleNational).';
    }
    return null;
  }
}

// Ordered: AU first, then NZ (closest neighbour), GB / IE (migrant tradies),
// IN / PH (large communities in AU construction), then US / CA.
const supportedCountries = <Country>[
  Country(
    code: 'AU',
    dialCode: '61',
    name: 'Australia',
    flag: '🇦🇺',
    exampleNational: '412 345 678',
    localFormatHint: '4XX XXX XXX',
    // AU mobiles: 9 digits, start with 4 (we drop the leading 0).
    // Pattern matches the 9-digit national number.
  ),
  Country(
    code: 'NZ',
    dialCode: '64',
    name: 'New Zealand',
    flag: '🇳🇿',
    exampleNational: '21 123 4567',
    localFormatHint: '2X XXX XXXX',
    // NZ mobiles: 8-9 digits, start with 2.
  ),
  Country(
    code: 'GB',
    dialCode: '44',
    name: 'United Kingdom',
    flag: '🇬🇧',
    exampleNational: '7700 900123',
    localFormatHint: '7XXX XXXXXX',
    // UK mobiles: 10 digits, start with 7.
  ),
  Country(
    code: 'IE',
    dialCode: '353',
    name: 'Ireland',
    flag: '🇮🇪',
    exampleNational: '85 123 4567',
    localFormatHint: '8X XXX XXXX',
    // Irish mobiles: 9 digits, start with 8.
  ),
  Country(
    code: 'IN',
    dialCode: '91',
    name: 'India',
    flag: '🇮🇳',
    exampleNational: '98765 43210',
    localFormatHint: 'XXXXX XXXXX',
    // Indian mobiles: 10 digits, start with 6/7/8/9.
  ),
  Country(
    code: 'PH',
    dialCode: '63',
    name: 'Philippines',
    flag: '🇵🇭',
    exampleNational: '917 123 4567',
    localFormatHint: '9XX XXX XXXX',
    // PH mobiles: 10 digits, start with 9.
  ),
  Country(
    code: 'US',
    dialCode: '1',
    name: 'United States',
    flag: '🇺🇸',
    exampleNational: '(555) 123-4567',
    localFormatHint: 'XXX XXX XXXX',
    // NANP: 10 digits, first digit 2-9.
  ),
  Country(
    code: 'CA',
    dialCode: '1',
    name: 'Canada',
    flag: '🇨🇦',
    exampleNational: '(416) 555-0123',
    localFormatHint: 'XXX XXX XXXX',
    // Same NANP rules as US.
  ),
];

// Regex map kept separate so the const list above stays a const expression.
// Looked up on construction below.
final Map<String, RegExp> _nationalRegexes = {
  'AU': RegExp(r'^4\d{8}$'),
  'NZ': RegExp(r'^2\d{7,8}$'),
  'GB': RegExp(r'^7\d{9}$'),
  'IE': RegExp(r'^8\d{8}$'),
  'IN': RegExp(r'^[6-9]\d{9}$'),
  'PH': RegExp(r'^9\d{9}$'),
  'US': RegExp(r'^[2-9]\d{9}$'),
  'CA': RegExp(r'^[2-9]\d{9}$'),
};

// Country.nationalRegex is overridden in this lookup so the const list above
// stays purely const. Use this from UI code to get the real regex.
RegExp nationalRegexFor(Country c) =>
    _nationalRegexes[c.code] ?? RegExp(r'^\d{6,15}$');

Country defaultCountry() =>
    supportedCountries.firstWhere((c) => c.code == 'AU');

Country? countryByCode(String code) {
  for (final c in supportedCountries) {
    if (c.code == code) return c;
  }
  return null;
}
