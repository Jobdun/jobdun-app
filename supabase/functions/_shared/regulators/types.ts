// LicenceAdapter — one implementation per state regulator.
// Edge Function `verify-licence` routes by licence_state into one of these.

export type AusState = "NSW" | "VIC" | "QLD" | "SA" | "WA" | "TAS" | "ACT" | "NT";

export type LicenceResult =
  | {
      status: "verified";
      holderName: string;
      expiresAt: Date | null;
      raw: unknown;
    }
  | {
      status: "failed";
      reason: "not_found" | "cancelled" | "suspended" | "unknown_response";
      detail: string;
      raw: unknown;
    }
  | {
      // Adapter could not produce a definitive answer — Edge Function routes
      // these to manual_review.
      status: "unknown";
      detail: string;
      raw: unknown;
    };

export interface LicenceAdapter {
  state: AusState;
  regulatorDisplayName: string;   // "NSW Fair Trading" — for user-facing copy
  verify(input: {
    licenceNumber: string;
    tradeClass: string;
  }): Promise<LicenceResult>;
}

// Decides whether a `failed` result is recoverable via manual upload.
// Matches the Hole 3 fraud-guard rule.
export function manualFallbackAllowed(result: LicenceResult): boolean {
  if (result.status === "verified") return false;
  if (result.status === "unknown") return true;
  return result.reason === "not_found" || result.reason === "unknown_response";
}
