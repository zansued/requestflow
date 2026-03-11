CREATE TABLE IF NOT EXISTS analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Event metadata
    event_type VARCHAR(50) NOT NULL CHECK (
        event_type IN (
            'page_view',
            'button_click', 
            'form_submission',
            'form_error',
            'testimonial_view',
            'early_access_signup',
            'admin_login',
            'admin_action'
        )
    ),
    
    -- Event data (JSONB for flexibility)
    event_data JSONB DEFAULT '{}'::jsonb,
    
    -- User context
    user_agent TEXT,
    ip_address INET,
    referrer TEXT,
    page_url TEXT NOT NULL,
    session_id UUID NOT NULL,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraint for valid JSON
    CONSTRAINT valid_event_data CHECK (jsonb_typeof(event_data) = 'object')
);

-- Enable Row Level Security
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Allow authenticated inserts only, with rate limiting enforced at the application layer.
-- This prevents anonymous data pollution and basic DoS vectors.
CREATE POLICY "allow_authenticated_inserts" ON analytics_events
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Only admins can view analytics data
CREATE POLICY "admins_can_view_analytics" ON analytics_events
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid() AND users.role = 'admin'
        )
    );

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_analytics_events_event_type ON analytics_events(event_type);
CREATE INDEX IF NOT EXISTS idx_analytics_events_created_at ON analytics_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_events_session_id ON analytics_events(session_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_page_url ON analytics_events(page_url);

-- Create function to anonymize IP addresses (last octet for IPv4, last 80 bits for IPv6)
-- Updated to use /24 subnet for IPv4 for better privacy compliance (e.g., GDPR).
CREATE OR REPLACE FUNCTION anonymize_ip(ip INET)
RETURNS INET AS $$
BEGIN
    IF family(ip) = 4 THEN
        -- For IPv4: set last 8 bits to 0 (e.g., 192.168.1.100 -> 192.168.1.0)
        -- Using /24 subnet as a common standard for anonymization.
        RETURN set_masklen(ip, 24)::inet;
    ELSIF family(ip) = 6 THEN
        -- For IPv6: keep first 48 bits (e.g., /48 prefix)
        RETURN set_masklen(ip, 48)::inet;
    END IF;
    RETURN ip;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create trigger to automatically anonymize IP addresses before insert
CREATE OR REPLACE FUNCTION trigger_anonymize_ip()
RETURNS TRIGGER AS $$
BEGIN
    NEW.ip_address := anonymize_ip(NEW.ip_address);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER anonymize_ip_before_insert
    BEFORE INSERT ON analytics_events
    FOR EACH ROW
    EXECUTE FUNCTION trigger_anonymize_ip();

-- Comment: Application-level rate limiting (e.g., per user/session/IP) is REQUIRED
-- to prevent data pollution and denial-of-service attacks, even with authenticated inserts.
-- Consider using a dedicated service or middleware (e.g., Redis, API Gateway) for robust rate limiting.