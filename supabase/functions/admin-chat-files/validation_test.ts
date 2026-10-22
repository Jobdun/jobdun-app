import { validateFile } from "./validation.ts";
function assert(value: unknown) {
  if (!value) throw Error("assertion failed");
}
Deno.test("accepts UTF8 text but rejects empty, oversized, active HTML, invalid UTF8 and MIME spoof", () => {
  const valid = validateFile(
    "notes.txt",
    "text/plain",
    new TextEncoder().encode("Site notes\nこんにちは"),
  );
  assert(valid.mime === "text/plain");
  for (
    const [name, mime, bytes] of [
      ["empty.txt", "text/plain", new Uint8Array()],
      ["large.txt", "text/plain", new Uint8Array(3145729)],
      [
        "evil.txt",
        "text/plain",
        new TextEncoder().encode("<!doctype html><script>alert(1)</script>"),
      ],
      ["bad.txt", "text/plain", new Uint8Array([255, 255])],
      ["fake.png", "image/png", new TextEncoder().encode("not png")],
      ["x.svg", "image/svg+xml", new TextEncoder().encode("<svg/>")],
    ] as const
  ) {
    let failed = false;
    try {
      validateFile(name, mime, bytes);
    } catch {
      failed = true;
    }
    assert(failed);
  }
});
Deno.test("rejects control/path filenames and oversized image dimensions", () => {
  for (const name of ["../file.txt", "x\r\n.txt", "x".repeat(181) + ".txt"]) {
    let failed = false;
    try {
      validateFile(name, "text/plain", new TextEncoder().encode("ok"));
    } catch {
      failed = true;
    }
    assert(failed);
  }
  const png = Uint8Array.from(
    atob(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==",
    ),
    (c) => c.charCodeAt(0),
  );
  assert(validateFile("image.png", "image/png", png).mime === "image/png");
  new DataView(png.buffer).setUint32(16, 99999);
  let failed = false;
  try {
    validateFile("image.png", "image/png", png);
  } catch {
    failed = true;
  }
  assert(failed);
});
Deno.test("PDF headers accept current versions and reject active actions and trailing HTML", () => {
  const encode = (s: string) => new TextEncoder().encode(s);
  for (const version of ["1.4", "1.7", "2.0"]) {
    assert(
      validateFile(
        "site.pdf",
        "application/pdf",
        encode(
          `%PDF-${version}\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF\n`,
        ),
      ).mime === "application/pdf",
    );
  }
  for (
    const text of [
      "%PDF-1.4\n1 0 obj\n<< /JS (alert) >>\nendobj\n%%EOF",
      "%PDF-1.4\n1 0 obj\nendobj\n%%EOF\n<html>",
    ]
  ) {
    let failed = false;
    try {
      validateFile("site.pdf", "application/pdf", encode(text));
    } catch {
      failed = true;
    }
    assert(failed);
  }
});
