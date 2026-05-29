import { z } from "zod";

export const MealLogInsert = z.object({
  description: z.string().min(1).max(2000).nullable().optional(),
  image_url: z.string().url().nullable().optional(),
  estimated_calories: z.number().int().min(0).nullable().optional(),
});
export type MealLogInsert = z.infer<typeof MealLogInsert>;

export const FoodItem = z.object({
  name: z.string().min(1).max(200),
  calories: z.number().min(0),
});
export type FoodItem = z.infer<typeof FoodItem>;

export const FoodAnalysisResult = z.object({
  items: z.array(FoodItem).min(1),
  total_calories: z.number().min(0),
});
export type FoodAnalysisResult = z.infer<typeof FoodAnalysisResult>;
