-- 01_create_profiles_and_invites.sql

-- Enable the uuid-ossp extension to generate UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create ENUM for User Roles
CREATE TYPE user_role AS ENUM ('chief', 'superAdmin', 'member', 'pending');

-- 1. Profiles Table
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  role user_role DEFAULT 'pending'::user_role NOT NULL,
  full_name TEXT,
  username TEXT UNIQUE,
  avatar_url TEXT,
  circle_id UUID, -- For future multi-tenant support
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable RLS for Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Policies for Profiles
CREATE POLICY "Public profiles are viewable by everyone in the circle."
  ON public.profiles FOR SELECT
  USING (true); -- In the future, restrict by circle_id

CREATE POLICY "Users can insert their own profile."
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile."
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- 2. Invites Table
CREATE TABLE public.invites (
  code TEXT PRIMARY KEY,
  created_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE, -- Null means system generated
  is_used BOOLEAN DEFAULT FALSE NOT NULL,
  used_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  circle_id UUID, -- For future multi-tenant support
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable RLS for Invites
ALTER TABLE public.invites ENABLE ROW LEVEL SECURITY;

-- Policies for Invites
-- Anyone can select an invite to check if it's valid
CREATE POLICY "Invites are viewable by anyone."
  ON public.invites FOR SELECT
  USING (true);

-- Only Admins/Chief can insert an invite (We will enforce this logic later or handle it via edge functions)
CREATE POLICY "Only admins can create invites."
  ON public.invites FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND (role = 'chief' OR role = 'superAdmin')
    )
  );

-- A user can update an invite to mark it as used when they sign up
CREATE POLICY "Users can update invite to mark as used."
  ON public.invites FOR UPDATE
  USING (true);

-- Function to handle new user creation automatically via Supabase Triggers (Optional, but recommended)
-- This creates a profile record whenever a new auth.users record is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger the function every time a user is created
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
