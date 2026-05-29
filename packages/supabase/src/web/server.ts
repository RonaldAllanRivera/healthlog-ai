import { createServerClient } from "@supabase/ssr";
import type { CookieOptions } from "@supabase/ssr";
import type { Database } from "../types.js";

type CookieStore = {
  get(name: string): { value: string } | undefined;
  set(name: string, value: string, options?: CookieOptions): void;
};

/**
 * Create a Supabase client for use in Next.js Server Components,
 * route handlers, and server actions. Pass the result of
 * `cookies()` from `next/headers`.
 */
export function createSupabaseServerClient(
  cookieStore: CookieStore,
  options: { url: string; anonKey: string },
) {
  return createServerClient<Database>(options.url, options.anonKey, {
    cookies: {
      get(name: string) {
        return cookieStore.get(name)?.value;
      },
      set(name: string, value: string, options: CookieOptions) {
        cookieStore.set(name, value, options);
      },
      remove(name: string, options: CookieOptions) {
        cookieStore.set(name, "", { ...options, maxAge: 0 });
      },
    },
  });
}
