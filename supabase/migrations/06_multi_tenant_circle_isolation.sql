-- 06_multi_tenant_circle_isolation.sql

-- 1. Create Circles Table
CREATE TABLE IF NOT EXISTS public.circles (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable RLS for Circles
ALTER TABLE public.circles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Circles are viewable by their members."
    ON public.circles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND (circle_id = circles.id OR role = 'chief')
        )
    );

-- 2. Create Follows Table for Cross-Circle Friendship
CREATE TYPE follow_status AS ENUM ('pending', 'accepted', 'rejected');

CREATE TABLE IF NOT EXISTS public.follows (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    follower_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    following_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    status follow_status DEFAULT 'pending' NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE(follower_id, following_id)
);

-- Enable RLS for Follows
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own follow relationships."
    ON public.follows FOR SELECT
    USING (auth.uid() = follower_id OR auth.uid() = following_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'chief'));

CREATE POLICY "Users can insert follow requests."
    ON public.follows FOR INSERT
    WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can update their own follow requests."
    ON public.follows FOR UPDATE
    USING (auth.uid() = follower_id OR auth.uid() = following_id);

-- 3. Add missing circle_id columns
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS circle_id UUID;
ALTER TABLE public.comments ADD COLUMN IF NOT EXISTS circle_id UUID;
ALTER TABLE public.likes ADD COLUMN IF NOT EXISTS circle_id UUID;

-- 4. Update RLS Policies for Strict Isolation

-- Function to get current user's circle_id
CREATE OR REPLACE FUNCTION public.get_my_circle_id()
RETURNS UUID AS $$
  SELECT circle_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE;

-- Function to check if user is chief
CREATE OR REPLACE FUNCTION public.is_chief()
RETURNS BOOLEAN AS $$
  SELECT role = 'chief' FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE;

-- Profiles: Chief can see all, others see same circle
DROP POLICY IF EXISTS "Public profiles are viewable by everyone in the circle." ON public.profiles;
CREATE POLICY "Profiles are viewable by circle members or chief or for discovery."
    ON public.profiles FOR SELECT
    USING (
        circle_id = public.get_my_circle_id() OR 
        public.is_chief() OR
        true -- Allow global discovery for search
    );

-- Profiles: Chief can update anyone (for blocking)
CREATE POLICY "Chief can update any profile."
    ON public.profiles FOR UPDATE
    USING (public.is_chief());

-- Messages: Same circle OR accepted follow relationship
DROP POLICY IF EXISTS "Users can view their own messages." ON public.messages;
CREATE POLICY "Messages are isolated by circle or follow relationship."
    ON public.messages FOR SELECT
    USING (
        circle_id = public.get_my_circle_id() OR
        EXISTS (
            SELECT 1 FROM public.follows 
            WHERE status = 'accepted' AND 
            ((follower_id = messages.sender_id AND following_id = messages.receiver_id) OR
             (follower_id = messages.receiver_id AND following_id = messages.sender_id))
        )
    );

-- Posts: Strict circle isolation
DROP POLICY IF EXISTS "Posts are viewable by approved members." ON public.posts;
CREATE POLICY "Posts are strictly isolated by circle."
    ON public.posts FOR SELECT
    USING (circle_id = public.get_my_circle_id());

-- Update Insert policies to enforce circle_id
DROP POLICY IF EXISTS "Approved members can insert posts." ON public.posts;
CREATE POLICY "Insert posts into own circle."
    ON public.posts FOR INSERT
    WITH CHECK (circle_id = public.get_my_circle_id());

-- Apply similar strict isolation to comments, likes, and live_sessions
DROP POLICY IF EXISTS "Comments are viewable by approved members." ON public.comments;
CREATE POLICY "Comments are isolated by circle." ON public.comments FOR SELECT USING (circle_id = public.get_my_circle_id());

DROP POLICY IF EXISTS "Likes are viewable by approved members." ON public.likes;
CREATE POLICY "Likes are isolated by circle." ON public.likes FOR SELECT USING (circle_id = public.get_my_circle_id());

DROP POLICY IF EXISTS "Live sessions are viewable by approved members." ON public.live_sessions;
CREATE POLICY "Live sessions are isolated by circle." ON public.live_sessions FOR SELECT USING (circle_id = public.get_my_circle_id());

-- Trigger to automatically assign circle_id from invite code
CREATE OR REPLACE FUNCTION public.assign_circle_from_invite()
RETURNS TRIGGER AS $$
DECLARE
    invite_circle_id UUID;
BEGIN
    -- This logic assumes we pass the invite code in some way during signup, 
    -- or we handle it in the app. For RLS safety, we'll let the app pass it for now, 
    -- but here is where we could enforce it.
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Enable Realtime for Follows
ALTER PUBLICATION supabase_realtime ADD TABLE public.follows;
