import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";

const styles = readFileSync("src/styles.css", "utf8");

describe("styles", () => {
  it("keeps motion optional for reduced-motion users", () => {
    expect(styles).toContain("@media (prefers-reduced-motion: reduce)");
    expect(styles).toContain("animation-duration: 0.001ms !important");
    expect(styles).toContain("transition-duration: 0.001ms !important");
  });
});
