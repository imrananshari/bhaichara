-- Table to store user public keys for E2EE
CREATE TABLE IF NOT EXISTS public.user_public_keys (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    public_key TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.user_public_keys ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Public keys are viewable by everyone" 
ON public.user_public_keys FOR SELECT 
USING (true);

CREATE POLICY "Users can manage their own public key" 
ON public.user_public_keys FOR ALL 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Update messages table for E2EE
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS is_encrypted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS iv TEXT; -- Initialization Vector for AES-GCM

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_public_keys_updated_at
    BEFORE UPDATE ON public.user_public_keys
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
