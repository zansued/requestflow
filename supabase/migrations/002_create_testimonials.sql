CREATE TABLE IF NOT EXISTS app_8c11f279.testimonials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_name VARCHAR(100) NOT NULL,
  author_role VARCHAR(100) NOT NULL,
  content TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  
  -- Constraints de validação
  CONSTRAINT testimonials_author_name_length CHECK (char_length(author_name) >= 2),
  CONSTRAINT testimonials_author_role_length CHECK (char_length(author_role) >= 2),
  CONSTRAINT testimonials_content_length CHECK (char_length(content) >= 10)
);

-- Enable Row Level Security
ALTER TABLE app_8c11f279.testimonials ENABLE ROW LEVEL SECURITY;

-- Create policy for public read access to active testimonials
CREATE POLICY "Allow public read access to active testimonials" 
ON app_8c11f279.testimonials 
FOR SELECT 
USING (is_active = true);

-- Create policy for admin insert access
-- Using auth.jwt() to safely extract the user ID and check role
CREATE POLICY "Allow admin insert access" 
ON app_8c11f279.testimonials 
FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app_8c11f279.users 
    WHERE id = (auth.jwt() ->> 'sub')::UUID AND role = 'admin'
  )
);

-- Create policy for admin update access
CREATE POLICY "Allow admin update access" 
ON app_8c11f279.testimonials 
FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM app_8c11f279.users 
    WHERE id = (auth.jwt() ->> 'sub')::UUID AND role = 'admin'
  )
);

-- Create policy for admin delete access
CREATE POLICY "Allow admin delete access" 
ON app_8c11f279.testimonials 
FOR DELETE 
USING (
  EXISTS (
    SELECT 1 FROM app_8c11f279.users 
    WHERE id = (auth.jwt() ->> 'sub')::UUID AND role = 'admin'
  )
);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_testimonials_active_order 
ON app_8c11f279.testimonials (is_active, display_order);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_testimonials_updated_at
  BEFORE UPDATE ON app_8c11f279.testimonials
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Comment: The schema name 'app_8c11f279' is assumed to be a project-specific identifier. For portability, consider using a variable or configuration to set this schema context.
-- Comment: RLS policies depend on the existence and proper security of the 'app_8c11f279.users' table. Ensure that table exists with appropriate RLS policies and that the 'role' column is protected against unauthorized modifications to prevent privilege escalation.