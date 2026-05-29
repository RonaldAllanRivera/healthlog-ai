import "react-native-url-polyfill/auto";
import { createClient } from "@supabase/supabase-js";
import AsyncStorage from "@react-native-async-storage/async-storage";
import type { Database } from "../types.js";

/**
 * Create a Supabase client for React Native. Sessions are persisted
 * in AsyncStorage so the user stays signed in across app launches.
 */
export function createSupabaseMobileClient(options: {
  url: string;
  anonKey: string;
}) {
  return createClient<Database>(options.url, options.anonKey, {
    auth: {
      storage: AsyncStorage as any,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    },
  });
}
