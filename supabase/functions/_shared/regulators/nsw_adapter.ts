// NSW Fair Trading licence adapter.
//
// STATUS (2026-05-25): scaffold only. The real lookup at
// https://verify.licence.nsw.gov.au is an HTML page, not a JSON API. To
// finish this adapter:
//   1. Fetch the lookup page once with curl, capture the form fields + the
//      response HTML for a known-active licence and a known-cancelled one.
//   2. Replace the deterministic branches below with a DOM parser
//      (`deno-dom` or regex on the rendered HTML).
//   3. Map the regulator's wording onto LicenceResult["reason"]:
//        "Cancelled" → "cancelled", "Suspended" → "suspended",
//        "No record"  → "not_found", anything else → "unknown_response".
//
// Until that's pinned, this stub lets the wizard flow be exercised
// end-to-end using deterministic test inputs.

import type { LicenceAdapter, LicenceResult } from "./types.ts";

export const nswAdapter: LicenceAdapter = {
  state: "NSW",
  regulatorDisplayName: "NSW Fair Trading",

  async verify({ licenceNumber, tradeClass }) {
    // Dev-mode shortcuts so the Flutter wizard can be exercised without the
    // live regulator. Remove these when the real scraper lands.
    if (licenceNumber.endsWith("00000")) {
      return ok({ holderName: "Test Tradie Pty Ltd", expiresInYears: 2 });
    }
    if (licenceNumber.endsWith("11111")) {
      return failed("cancelled", "Cancelled per NSW Fair Trading (dev stub)");
    }
    if (licenceNumber.endsWith("22222")) {
      return failed("suspended", "Suspended per NSW Fair Trading (dev stub)");
    }
    if (licenceNumber.endsWith("33333")) {
      return failed("not_found", "No record found (dev stub)");
    }
    if (licenceNumber.endsWith("44444")) {
      return unknown("Adapter timeout (dev stub)");
    }

    // Real path — to be implemented once the scraper is pinned.
    // For now, treat any other input as "unknown" so it routes to manual review.
    return unknown(
      `NSW adapter not yet implemented for licence ${licenceNumber} / class ${tradeClass}`,
    );
  },
};

function ok(args: { holderName: string; expiresInYears: number }): LicenceResult {
  const expiresAt = new Date();
  expiresAt.setFullYear(expiresAt.getFullYear() + args.expiresInYears);
  return {
    status: "verified",
    holderName: args.holderName,
    expiresAt,
    raw: { source: "nsw_adapter_stub" },
  };
}

function failed(
  reason: "not_found" | "cancelled" | "suspended" | "unknown_response",
  detail: string,
): LicenceResult {
  return { status: "failed", reason, detail, raw: { source: "nsw_adapter_stub" } };
}

function unknown(detail: string): LicenceResult {
  return { status: "unknown", detail, raw: { source: "nsw_adapter_stub" } };
}
