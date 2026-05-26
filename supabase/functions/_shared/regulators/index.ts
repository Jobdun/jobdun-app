import type { AusState, LicenceAdapter } from "./types.ts";
import { nswAdapter } from "./nsw_adapter.ts";

const ADAPTERS: Partial<Record<AusState, LicenceAdapter>> = {
  NSW: nswAdapter,
  // VIC, QLD, SA, WA, TAS, ACT, NT — Phase 7+.
};

export function adapterFor(state: AusState): LicenceAdapter | null {
  return ADAPTERS[state] ?? null;
}

export const supportedStates = Object.keys(ADAPTERS) as AusState[];
