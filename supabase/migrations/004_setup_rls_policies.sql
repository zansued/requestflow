-- Enable RLS on all tables
ALTER TABLE app_8c11f279.early_access_signups ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_8c11f279.testimonials ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_8c11f279.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_8c11f279.analytics_events ENABLE ROW LEVEL SECURITY;

-- Early Access Signups Policies
-- Anyone can insert (sign up)
CREATE POLICY "visitors_can_insert_early_access" 
ON app_8c11f279.early_access_signups 
FOR INSERT 
TO anon 
WITH CHECK (true);

-- Only admins can view signups
CREATE POLICY "admins_can_view_early_access" 
ON app_8c11f279.early_access_signups 
FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM app_8c11f279.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Only admins can delete signups
CREATE POLICY "admins_can_delete_early_access" 
ON app_8c11f279.early_access_signups 
FOR DELETE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM app_8c11f279.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Testimonials Policies
-- Anyone can view active testimonials
CREATE POLICY "public_can_view_active_testimonials" 
ON app_8c11f279.testimonials 
FOR SELECT 
TO anon 
USING (is_active = true);

-- Authenticated users with editor or admin role can insert testimonials
CREATE POLICY "editors_can_insert_testimonials" 
ON app_8c11f279.testimonials 
FOR INSERT 
TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app_8c11f279.users 
    WHERE id = auth.uid() AND role IN ('admin', 'editor')
  )
);

-- Authenticated users with editor or admin role can select all testimonials
CREATE POLICY "editors_can_select_testimonials" 
ON app_8c11f279.testimonials 
FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM app_8c11f279.users 
    WHERE id = auth.uid() AND role IN ('admin', 'editor')
  )
);

-- Authenticated users with editor or admin role can update testimonials
CREATE POLICY "editors_can_update_testimonials" 
ON app_8c11f279.testimonials 
FOR UPDATE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM app_8c11f279.users 
    WHERE id = auth.uid() AND role IN ('admin', 'editor')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app_8c11f279.users 
    WHERE id = auth.uid() AND role IN ('admin', 'editor')
  )
);

-- Only admins can delete testimonials
CREATE POLICY "admins_can_delete_testimonials" 
ON app_8c11f279.testimonials 
FOR DELETE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM app_8c11f279.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Users Policies
-- Users can view their own profile
CREATE POLICY "users_can_view_own_profile" 
ON app_8c11f279.users 
FOR SELECT 
TO authenticated 
USING (id = auth.uid());

-- Only admins can create/update/delete users
CREATE POLICY "admins_can_manage_users" 
ON app_8c11f279.users 
FOR ALL 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM app_8c11f279.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app_8c11f279.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Analytics Events Policies
-- Anyone can insert analytics events
CREATE POLICY "public_can_insert_analytics" 
ON app_8c11f279.analytics_events 
FOR INSERT 
TO anon 
WITH CHECK (true);

-- Only admins can view analytics
CREATE POLICY "admins_can_view_analytics" 
ON app_8c11f279.analytics_events 
FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM app_8c11f279.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_testimonials_active_order 
ON app_8c11f279.testimonials (is_active, display_order);

CREATE INDEX IF NOT EXISTS idx_early_access_signup_date 
ON app_8c11f279.early_access_signups (signup_date);

CREATE INDEX IF NOT EXISTS idx_analytics_event_type 
ON app_8c11f279.analytics_events (event_type);

CREATE INDEX IF NOT EXISTS idx_analytics_created_at 
ON app_8c11f279.analytics_events (created_at);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA app_8c11f279 TO anon, authenticated;
-- Revoke overly permissive grant and replace with specific grants
GRANT SELECT, INSERT, UPDATE, DELETE ON app_8c11f279.early_access_signups TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app_8c11f279.testimonials TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app_8c11f279.users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app_8c11f279.analytics_events TO authenticated;
GRANT INSERT ON app_8c11f279.early_access_signups TO anon;
GRANT INSERT ON app_8c11f279.analytics_events TO anon;
GRANT SELECT ON app_8c11f279.testimonials TO anon;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA app_8c11f279 TO authenticated;