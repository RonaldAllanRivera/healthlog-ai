import { describe, it, expect } from "vitest";
import { PLAN_LIMITS, isOverLimit, type Plan } from "../src/plans.js";

describe("PLAN_LIMITS", () => {
  it("defines limits for free, basic, pro", () => {
    expect(PLAN_LIMITS.free.bpScans).toBe(10);
    expect(PLAN_LIMITS.free.mealScans).toBe(10);
    expect(PLAN_LIMITS.basic.bpScans).toBe(100);
    expect(PLAN_LIMITS.basic.mealScans).toBe(100);
    expect(PLAN_LIMITS.pro.bpScans).toBe(Infinity);
    expect(PLAN_LIMITS.pro.mealScans).toBe(Infinity);
  });

  it("monotonically increases free → basic → pro for every limit", () => {
    const kinds = ["bpScans", "mealScans"] as const;
    for (const kind of kinds) {
      expect(PLAN_LIMITS.basic[kind]).toBeGreaterThanOrEqual(
        PLAN_LIMITS.free[kind],
      );
      expect(PLAN_LIMITS.pro[kind]).toBeGreaterThanOrEqual(
        PLAN_LIMITS.basic[kind],
      );
    }
  });
});

describe("isOverLimit", () => {
  it("returns false when usage is below the limit", () => {
    expect(isOverLimit("free", "bp", 0)).toBe(false);
    expect(isOverLimit("free", "bp", 9)).toBe(false);
    expect(isOverLimit("basic", "meal", 50)).toBe(false);
  });

  it("returns true when usage equals or exceeds the limit", () => {
    expect(isOverLimit("free", "bp", 10)).toBe(true);
    expect(isOverLimit("free", "meal", 11)).toBe(true);
    expect(isOverLimit("basic", "bp", 100)).toBe(true);
  });

  it("returns false for pro at any reasonable count", () => {
    expect(isOverLimit("pro", "bp", 1_000_000)).toBe(false);
    expect(isOverLimit("pro", "meal", Number.MAX_SAFE_INTEGER)).toBe(false);
  });

  it("typechecks Plan as keyof PLAN_LIMITS", () => {
    const p: Plan = "free";
    expect(p in PLAN_LIMITS).toBe(true);
  });
});
