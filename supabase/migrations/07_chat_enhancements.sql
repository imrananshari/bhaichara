-- Update messages table for premium features
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'text';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Policy to allow users to "Delete for everyone" (update deleted_at)
CREATE POLICY "Users can delete their own messages for everyone."
  ON public.messages FOR UPDATE
  USING (auth.uid() = sender_id);
