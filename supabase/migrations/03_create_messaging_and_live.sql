-- 03_create_messaging_and_live.sql

-- 1. Messages Table (for 1-on-1 and Group Chats)
CREATE TABLE public.messages (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  -- For 1-on-1: receiver_id is set. For Groups: group_id is set.
  receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  group_id UUID, -- Placeholder for future group chats table
  content TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT single_receiver CHECK (
    (receiver_id IS NOT NULL AND group_id IS NULL) OR 
    (receiver_id IS NULL AND group_id IS NOT NULL)
  )
);

-- Enable RLS
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own messages."
  ON public.messages FOR SELECT
  USING (
    auth.uid() = sender_id OR 
    auth.uid() = receiver_id
    -- Future: OR EXISTS (SELECT 1 FROM group_members WHERE user_id = auth.uid() AND group_id = messages.group_id)
  );

CREATE POLICY "Users can insert messages."
  ON public.messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND role IN ('chief', 'superAdmin', 'member')
    )
  );

-- 2. Live Sessions Table
CREATE TABLE public.live_sessions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  host_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  status TEXT CHECK (status IN ('live', 'ended')) DEFAULT 'live' NOT NULL,
  circle_id UUID,
  started_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  ended_at TIMESTAMPTZ
);

-- Enable RLS
ALTER TABLE public.live_sessions ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Live sessions are viewable by approved members."
  ON public.live_sessions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND role IN ('chief', 'superAdmin', 'member')
    )
  );

CREATE POLICY "Approved members can insert live sessions."
  ON public.live_sessions FOR INSERT
  WITH CHECK (
    auth.uid() = host_id AND
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND role IN ('chief', 'superAdmin', 'member')
    )
  );

CREATE POLICY "Hosts can update their own live sessions (end them)."
  ON public.live_sessions FOR UPDATE
  USING (auth.uid() = host_id);


-- Turn on Supabase Realtime for these tables
-- You usually need to do this through the Supabase Dashboard, but this is the SQL equivalent
begin;
  -- remove the supabase_realtime publication
  drop publication if exists supabase_realtime;
  
  -- re-create the publication and add the tables to it
  create publication supabase_realtime;
  alter publication supabase_realtime add table public.posts;
  alter publication supabase_realtime add table public.comments;
  alter publication supabase_realtime add table public.likes;
  alter publication supabase_realtime add table public.messages;
  alter publication supabase_realtime add table public.live_sessions;
  alter publication supabase_realtime add table public.profiles;
commit;
