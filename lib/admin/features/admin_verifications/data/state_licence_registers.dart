/// Official state/territory building-licence registers, for one-click admin
/// verification. Australia has eight separate licensing regimes with no national
/// register, so the admin must check each trade's licence on the correct state
/// regulator's public search page. This is static reference data — a const map,
/// not a DB table.
///
/// URLs are the official public search entry points as at 2026-05. If a
/// regulator moves its search tool, update the URL here.
class LicenceRegister {
  const LicenceRegister({
    required this.state,
    required this.regulator,
    required this.url,
    required this.searchBy,
  });

  /// State/territory code: NSW/VIC/QLD/SA/WA/TAS/ACT/NT.
  final String state;

  /// Plain-English regulator name shown on the admin link.
  final String regulator;

  /// Official public licence-search page.
  final String url;

  /// What the register lets you search by (admin hint).
  final String searchBy;
}

const Map<String, LicenceRegister> kStateLicenceRegisters = {
  'NSW': LicenceRegister(
    state: 'NSW',
    regulator: 'NSW Fair Trading',
    url:
        'https://www.fairtrading.nsw.gov.au/help-centre/online-tools/home-building-licence-check',
    searchBy: 'Licence no. / name',
  ),
  'VIC': LicenceRegister(
    state: 'VIC',
    regulator: 'Victorian Building Authority',
    url: 'https://www.vba.vic.gov.au/tools/find-practitioner',
    searchBy: 'Name / registration no.',
  ),
  'QLD': LicenceRegister(
    state: 'QLD',
    regulator: 'QBCC',
    url: 'https://my.qbcc.qld.gov.au/s/qbcc-licensee-register',
    searchBy: 'Licence no. / name',
  ),
  'SA': LicenceRegister(
    state: 'SA',
    regulator: 'Consumer & Business Services',
    url: 'https://www.cbs.sa.gov.au/find-a-licence-holder',
    searchBy: 'Name / licence no.',
  ),
  'WA': LicenceRegister(
    state: 'WA',
    regulator: 'Building & Energy (DEMIRS)',
    url:
        'https://www.commerce.wa.gov.au/building-and-energy/building-and-energy-licence-search',
    searchBy: 'Licence no. / name',
  ),
  'TAS': LicenceRegister(
    state: 'TAS',
    regulator: 'CBOS (My Licence)',
    url:
        'https://www.cbos.tas.gov.au/topics/licensing-and-registration/search-licensed-occupations',
    searchBy: 'Name / licence no.',
  ),
  'ACT': LicenceRegister(
    state: 'ACT',
    regulator: 'Access Canberra',
    url:
        'https://www.accesscanberra.act.gov.au/business-and-work/public-registers',
    searchBy: 'Name / licence no.',
  ),
  'NT': LicenceRegister(
    state: 'NT',
    regulator: 'Building Practitioners Board',
    url: 'https://bpb.nt.gov.au',
    searchBy: 'Name / registration no.',
  ),
};

/// Look up the official register for a state code (case-insensitive). Returns
/// null for an unknown, empty, or null state.
LicenceRegister? licenceRegisterFor(String? state) {
  if (state == null || state.trim().isEmpty) return null;
  return kStateLicenceRegisters[state.trim().toUpperCase()];
}
