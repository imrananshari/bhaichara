-- Run this in Supabase Dashboard → SQL Editor

-- 1. Add email column to profiles table (if not exists)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- 2. Fix the handle_new_user trigger to properly capture Google OAuth data
--    Google sends name as 'name' or 'full_name' and avatar as 'avatar_url' or 'picture'
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url, email)
  VALUES (
    new.id,
    COALESCE(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name'
    ),
    COALESCE(
      new.raw_user_meta_data->>'avatar_url',
      new.raw_user_meta_data->>'picture'
    ),
    new.email
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = COALESCE(
      EXCLUDED.full_name,
      public.profiles.full_name
    ),
    avatar_url = COALESCE(
      EXCLUDED.avatar_url,
      public.profiles.avatar_url
    ),
    email = COALESCE(
      EXCLUDED.email,
      public.profiles.email
    );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
