import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "../types.js";

/**
 * Create a Supabase client for use in Next.js Client Components.
 */
export function createSupabaseBrowserClient(options: {
  url: string;
  anonKey: string;
}) {
  return createBrowserClient<Database>(options.url, options.anonKey);
}
