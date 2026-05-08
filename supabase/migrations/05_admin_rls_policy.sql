-- Run this in Supabase Dashboard → SQL Editor

-- Give 'chief' and 'superAdmin' users the ability to update other profiles
-- Note: 'Users can update own profile' policy still exists and is not affected.

CREATE POLICY "Admins can update other profiles."
  ON public.profiles FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND (role = 'chief' OR role = 'superAdmin')
    )
  );
