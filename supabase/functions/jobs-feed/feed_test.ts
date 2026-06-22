import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { clampLimit, FEED_COLUMNS, MAX_LIMIT } from "./feed.ts";

// Drift guard: this canonical copy must equal `feedColumns` in
// lib/features/jobs/data/datasources/job_remote_datasource.dart. The app parses
// the function's rows with JobModel.fromJson — update BOTH sides together.
const DART_FEED_COLUMNS =
  "id, builder_id, title, description, suburb, state, postcode, " +
  "trade_type_required, budget_amount, pricing_unit, pricing_type, urgency, " +
  "requires_verified, requires_white_card, application_count, view_count, " +
  "status, published_at, created_at, updated_at, " +
  "latitude, longitude, formatted_address, place_id";

Deno.test("FEED_COLUMNS matches the Dart feedColumns projection", () => {
  assertEquals(FEED_COLUMNS, DART_FEED_COLUMNS);
});

Deno.test("clampLimit caps upward (client can never widen the query)", () => {
  assertEquals(clampLimit(1000), MAX_LIMIT);
  assertEquals(clampLimit(21), MAX_LIMIT);
  assertEquals(clampLimit(20), 20);
  assertEquals(clampLimit(7), 7);
});

Deno.test("clampLimit floors to >= 1 and ignores junk input", () => {
  assertEquals(clampLimit(0), 1);
  assertEquals(clampLimit(-5), 1);
  assertEquals(clampLimit(7.9), 7);
  assertEquals(clampLimit(undefined), MAX_LIMIT);
  assertEquals(clampLimit("50"), MAX_LIMIT);
  assertEquals(clampLimit(null), MAX_LIMIT);
  assertEquals(clampLimit(NaN), MAX_LIMIT);
});
