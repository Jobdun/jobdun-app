import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { clampLimit, FEED_COLUMNS, MAX_LIMIT } from "./feed.ts";

Deno.test("FEED_COLUMNS matches the Dart feedColumns projection", () => {
  // Read the app's source: a second hand-maintained copy can drift together
  // with the Edge Function while the real mobile projection changes.
  const source = Deno.readTextFileSync(
    new URL(
      "../../../lib/features/jobs/data/datasources/job_remote_datasource.dart",
      import.meta.url,
    ),
  );
  const declaration = source.match(
    /static const String feedColumns =([\s\S]*?);/,
  );
  if (!declaration) throw new Error("Dart feedColumns declaration not found");
  const dartColumns = [...declaration[1].matchAll(/'([^']*)'/g)]
    .map((match) => match[1]).join("");
  assertEquals(FEED_COLUMNS, dartColumns);
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
