import { describe, it, expect } from "vitest";
import {
  BpReadingInsert,
  BpAnalysisResult,
  MealLogInsert,
  FoodAnalysisResult,
  SubscriptionRow,
  UsageTrackingRow,
} from "../src/schemas/index.js";

describe("BpReadingInsert", () => {
  it("accepts a minimal valid reading", () => {
    expect(
      BpReadingInsert.parse({ systolic: 120, diastolic: 80 }),
    ).toEqual({ systolic: 120, diastolic: 80 });
  });

  it("accepts all optional fields", () => {
    const r = BpReadingInsert.parse({
      systolic: 120,
      diastolic: 80,
      pulse: 70,
      notes: "morning reading",
      image_url: "https://example.com/x.jpg",
    });
    expect(r.pulse).toBe(70);
  });

  it("rejects systolic out of range", () => {
    expect(() => BpReadingInsert.parse({ systolic: 9999, diastolic: 80 }))
      .toThrow();
    expect(() => BpReadingInsert.parse({ systolic: 10, diastolic: 80 }))
      .toThrow();
  });

  it("rejects diastolic out of range", () => {
    expect(() => BpReadingInsert.parse({ systolic: 120, diastolic: 9999 }))
      .toThrow();
  });

  it("rejects non-integer systolic", () => {
    expect(() => BpReadingInsert.parse({ systolic: 120.5, diastolic: 80 }))
      .toThrow();
  });

  it("rejects malformed image_url", () => {
    expect(() =>
      BpReadingInsert.parse({
        systolic: 120,
        diastolic: 80,
        image_url: "not-a-url",
      }),
    ).toThrow();
  });
});

describe("BpAnalysisResult", () => {
  it("requires systolic, diastolic; allows null pulse", () => {
    const r = BpAnalysisResult.parse({
      systolic: 120,
      diastolic: 80,
      pulse: null,
    });
    expect(r.pulse).toBeNull();
  });
});

describe("MealLogInsert", () => {
  it("accepts a minimal entry with just description", () => {
    expect(MealLogInsert.parse({ description: "apple" }))
      .toEqual({ description: "apple" });
  });

  it("rejects negative calories", () => {
    expect(() =>
      MealLogInsert.parse({ description: "x", estimated_calories: -1 }),
    ).toThrow();
  });

  it("accepts zero calories", () => {
    expect(
      MealLogInsert.parse({ description: "water", estimated_calories: 0 }),
    ).toEqual({ description: "water", estimated_calories: 0 });
  });
});

describe("FoodAnalysisResult", () => {
  it("parses a typical AI response", () => {
    const r = FoodAnalysisResult.parse({
      items: [{ name: "apple", calories: 95 }],
      total_calories: 95,
    });
    expect(r.items).toHaveLength(1);
  });

  it("rejects empty items array", () => {
    expect(() =>
      FoodAnalysisResult.parse({ items: [], total_calories: 0 }),
    ).toThrow();
  });
});

describe("SubscriptionRow", () => {
  it("accepts free plan with active status", () => {
    expect(
      SubscriptionRow.parse({
        id: "11111111-1111-1111-1111-111111111111",
        user_id: "22222222-2222-2222-2222-222222222222",
        stripe_customer_id: null,
        stripe_subscription_id: null,
        plan: "free",
        status: "active",
        current_period_end: null,
      }),
    ).toMatchObject({ plan: "free", status: "active" });
  });

  it("rejects invalid plan name", () => {
    expect(() =>
      SubscriptionRow.parse({
        id: "11111111-1111-1111-1111-111111111111",
        user_id: "22222222-2222-2222-2222-222222222222",
        stripe_customer_id: null,
        stripe_subscription_id: null,
        plan: "platinum",
        status: "active",
        current_period_end: null,
      }),
    ).toThrow();
  });
});

describe("UsageTrackingRow", () => {
  it("accepts a well-formed month", () => {
    const r = UsageTrackingRow.parse({
      user_id: "33333333-3333-3333-3333-333333333333",
      month: "2026-05",
      bp_scans_used: 3,
      meal_scans_used: 1,
    });
    expect(r.month).toBe("2026-05");
  });

  it("rejects malformed month string", () => {
    expect(() =>
      UsageTrackingRow.parse({
        user_id: "33333333-3333-3333-3333-333333333333",
        month: "2026-5",
        bp_scans_used: 0,
        meal_scans_used: 0,
      }),
    ).toThrow();
  });

  it("rejects negative counters", () => {
    expect(() =>
      UsageTrackingRow.parse({
        user_id: "33333333-3333-3333-3333-333333333333",
        month: "2026-05",
        bp_scans_used: -1,
        meal_scans_used: 0,
      }),
    ).toThrow();
  });
});
