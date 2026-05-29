export const PLAN_LIMITS = {
  free:  { bpScans: 10,        mealScans: 10        },
  basic: { bpScans: 100,       mealScans: 100       },
  pro:   { bpScans: Infinity,  mealScans: Infinity  },
} as const;

export type Plan = keyof typeof PLAN_LIMITS;

export function isOverLimit(
  plan: Plan,
  kind: "bp" | "meal",
  used: number,
): boolean {
  const limit =
    kind === "bp" ? PLAN_LIMITS[plan].bpScans : PLAN_LIMITS[plan].mealScans;
  return used >= limit;
}
