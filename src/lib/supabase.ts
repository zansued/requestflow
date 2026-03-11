import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables. Check .env file.');
}

const isValidSupabaseUrl = (url: string): boolean => {
  try {
    const parsedUrl = new URL(url);
    return parsedUrl.protocol === 'https:' && parsedUrl.hostname.includes('.supabase.co');
  } catch {
    return false;
  }
};

const isValidAnonKey = (key: string): boolean => {
  return typeof key === 'string' && key.length > 20 && key.startsWith('eyJ');
};

if (!isValidSupabaseUrl(supabaseUrl)) {
  throw new Error('Invalid Supabase URL format. Must be a valid HTTPS URL ending with .supabase.co');
}

if (!isValidAnonKey(supabaseAnonKey)) {
  throw new Error('Invalid Supabase anonymous key format. Must be a valid JWT token.');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);