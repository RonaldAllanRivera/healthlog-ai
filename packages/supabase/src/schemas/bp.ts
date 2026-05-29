import { z } from "zod";

export const BpReadingInsert = z.object({
  systolic: z.number().int().min(40).max(300),
  diastolic: z.number().int().min(30).max(200),
  pulse: z.number().int().min(20).max(250).nullable().optional(),
  notes: z.string().max(1000).nullable().optional(),
  image_url: z.string().url().nullable().optional(),
});
export type BpReadingInsert = z.infer<typeof BpReadingInsert>;

export const BpAnalysisResult = z.object({
  systolic: z.number().int().min(40).max(300),
  diastolic: z.number().int().min(30).max(200),
  pulse: z.number().int().min(20).max(250).nullable(),
});
export type BpAnalysisResult = z.infer<typeof BpAnalysisResult>;
