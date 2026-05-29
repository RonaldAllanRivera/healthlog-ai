import { z } from "zod";

export const MONTH_REGEX = /^\d{4}-\d{2}$/;

export const UsageTrackingRow = z.object({
  user_id: z.string().uuid(),
  month: z.string().regex(MONTH_REGEX, "Month must be YYYY-MM"),
  bp_scans_used: z.number().int().min(0),
  meal_scans_used: z.number().int().min(0),
});
export type UsageTrackingRow = z.infer<typeof UsageTrackingRow>;
