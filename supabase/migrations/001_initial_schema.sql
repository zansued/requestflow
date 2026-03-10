CREATE TYPE IF NOT EXISTS app_8c11f279.user_role AS ENUM ('admin', 'approver', 'user');

CREATE TABLE IF NOT EXISTS app_8c11f279.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    role app_8c11f279.user_role NOT NULL DEFAULT 'user',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app_8c11f279.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    settings JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app_8c11f279.user_organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES app_8c11f279.users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES app_8c11f279.organizations(id) ON DELETE CASCADE,
    role app_8c11f279.user_role NOT NULL DEFAULT 'user',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, organization_id)
);

CREATE INDEX IF NOT EXISTS idx_users_email ON app_8c11f279.users(email);
CREATE INDEX IF NOT EXISTS idx_organizations_slug ON app_8c11f279.organizations(slug);
CREATE INDEX IF NOT EXISTS idx_user_organizations_user_id ON app_8c11f279.user_organizations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_org_id ON app_8c11f279.user_organizations(organization_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_user_org_role ON app_8c11f279.user_organizations(user_id, organization_id, role);
CREATE INDEX IF NOT EXISTS idx_users_role ON app_8c11f279.users(role);
CREATE INDEX IF NOT EXISTS idx_organizations_created_at ON app_8c11f279.organizations(created_at);

CREATE OR REPLACE FUNCTION app_8c11f279.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON app_8c11f279.users
    FOR EACH ROW
    EXECUTE FUNCTION app_8c11f279.update_updated_at_column();

CREATE TRIGGER update_organizations_updated_at
    BEFORE UPDATE ON app_8c11f279.organizations
    FOR EACH ROW
    EXECUTE FUNCTION app_8c11f279.update_updated_at_column();

CREATE TRIGGER update_user_organizations_updated_at
    BEFORE UPDATE ON app_8c11f279.user_organizations
    FOR EACH ROW
    EXECUTE FUNCTION app_8c11f279.update_updated_at_column();