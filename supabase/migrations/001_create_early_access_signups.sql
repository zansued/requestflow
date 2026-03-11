CREATE TABLE IF NOT EXISTS app_8c11f279.early_access_signups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    signup_date TIMESTAMP DEFAULT now() NOT NULL,
    marketing_consent BOOLEAN DEFAULT true NOT NULL
);

ALTER TABLE app_8c11f279.early_access_signups ENABLE ROW LEVEL SECURITY;

-- Allow public signups
CREATE POLICY "visitors_can_insert" ON app_8c11f279.early_access_signups
    FOR INSERT
    WITH CHECK (email IS NOT NULL);

-- Restrict all other operations to authenticated users only (commonly via service role)
-- Adjust role name as needed for your application's access pattern.
CREATE POLICY "service_role_full_access" ON app_8c11f279.early_access_signups
    FOR ALL
    USING (current_user = 'service_role')
    WITH CHECK (current_user = 'service_role');

-- Optional: Add a basic uniqueness constraint for email if business logic requires it.
-- Consider using `citext` extension or lower-casing for case-insensitive uniqueness.
-- ALTER TABLE app_8c11f279.early_access_signups ADD CONSTRAINT email_unique UNIQUE (email);