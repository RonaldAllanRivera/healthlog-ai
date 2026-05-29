import { z } from "zod";

export const PLANS = ["free", "basic", "pro"] as const;
export const STATUSES = ["active", "canceled", "past_due"] as const;

export const SubscriptionRow = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  stripe_customer_id: z.string().nullable(),
  stripe_subscription_id: z.string().nullable(),
  plan: z.enum(PLANS),
  status: z.enum(STATUSES),
  current_period_end: z.string().datetime().nullable(),
});
export type SubscriptionRow = z.infer<typeof SubscriptionRow>;
