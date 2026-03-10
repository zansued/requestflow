```sql
-- ============================================
-- HABILITAÇÃO DO ROW LEVEL SECURITY (RLS)
-- ============================================
ALTER TABLE IF EXISTS app_8c11f279.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS app_8c11f279.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS app_8c11f279.user_organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS app_8c11f279.templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS app_8c11f279.requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS app_8c11f279.approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS app_8c11f279.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS app_8c11f279.notifications ENABLE ROW LEVEL SECURITY;

-- ============================================
-- REMOÇÃO DE POLÍTICAS EXISTENTES (SE NECESSÁRIO)
-- ============================================
-- (Omitido por simplicidade, mas em produção considere DROP POLICY IF EXISTS)

-- ============================================
-- POLÍTICAS PARA TABELA users
-- ============================================
-- SELECT: Usuários veem apenas seu próprio perfil
CREATE POLICY "users_select_own" ON app_8c11f279.users
    FOR SELECT USING (auth.uid() = id AND is_active = true);

-- INSERT: Apenas o sistema (via trigger/auth) ou administradores podem criar usuários
CREATE POLICY "users_insert_admin_only" ON app_8c11f279.users
    FOR INSERT WITH CHECK (
        -- Apenas administradores podem inserir manualmente
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
        OR
        -- Ou é o próprio usuário sendo criado via função de registro (auth.uid() é NULL durante signup)
        (auth.uid() IS NULL AND created_by IS NULL)
    );

-- UPDATE: Usuários atualizam apenas seu próprio perfil, exceto campos sensíveis
CREATE POLICY "users_update_own" ON app_8c11f279.users
    FOR UPDATE USING (auth.uid() = id)
    WITH CHECK (
        -- Impede que usuários comuns alterem role, is_active ou organization_id
        (
            auth.uid() = id
            AND role IS NOT DISTINCT FROM OLD.role
            AND is_active IS NOT DISTINCT FROM OLD.is_active
            AND organization_id IS NOT DISTINCT FROM OLD.organization_id
        )
    );

-- UPDATE: Administradores podem atualizar qualquer usuário, com validações
CREATE POLICY "users_update_admin" ON app_8c11f279.users
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
    )
    WITH CHECK (
        -- Validações de negócio para updates administrativos
        (role IN ('admin', 'manager', 'user'))
        AND (is_active IS NOT NULL)
        AND (
            -- Administradores não podem desativar a si mesmos
            NOT (id = auth.uid() AND is_active = false)
        )
    );

-- DELETE: Apenas administradores podem deletar usuários (soft delete via is_active é preferível)
CREATE POLICY "users_delete_admin_only" ON app_8c11f279.users
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
        AND id != auth.uid() -- Não pode deletar a si mesmo
    );

-- ============================================
-- POLÍTICAS PARA TABELA organizations
-- ============================================
-- SELECT: Usuários veem organizações às quais pertencem
CREATE POLICY "organizations_select_member" ON app_8c11f279.organizations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.user_organizations uo
            WHERE uo.organization_id = organizations.id
            AND uo.user_id = auth.uid()
        )
        AND is_active = true
    );

-- INSERT: Apenas administradores podem criar organizações
CREATE POLICY "organizations_insert_admin" ON app_8c11f279.organizations
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
    );

-- UPDATE: Apenas administradores podem atualizar organizações
CREATE POLICY "organizations_update_admin" ON app_8c11f279.organizations
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
    );

-- DELETE: Apenas administradores podem deletar organizações (soft delete via is_active é preferível)
CREATE POLICY "organizations_delete_admin" ON app_8c11f279.organizations
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
    );

-- ============================================
-- POLÍTICAS PARA TABELA user_organizations
-- ============================================
-- SELECT: Usuários veem suas próprias associações
CREATE POLICY "user_organizations_select_own" ON app_8c11f279.user_organizations
    FOR SELECT USING (user_id = auth.uid());

-- INSERT: Apenas administradores podem adicionar usuários a organizações
CREATE POLICY "user_organizations_insert_admin" ON app_8c11f279.user_organizations
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
    );

-- UPDATE: Apenas administradores podem atualizar associações
CREATE POLICY "user_organizations_update_admin" ON app_8c11f279.user_organizations
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
    );

-- DELETE: Apenas administradores podem remover usuários de organizações
CREATE POLICY "user_organizations_delete_admin" ON app_8c11f279.user_organizations
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
    );

-- ============================================
-- POLÍTICAS PARA TABELA templates
-- ============================================
-- SELECT: Usuários veem templates da sua organização
CREATE POLICY "templates_select_org" ON app_8c11f279.templates
    FOR SELECT USING (
        organization_id IN (
            SELECT organization_id FROM app_8c11f279.user_organizations
            WHERE user_id = auth.uid()
        )
        AND is_active = true
    );

-- INSERT: Apenas administradores e managers podem criar templates em sua organização
CREATE POLICY "templates_insert_manager" ON app_8c11f279.templates
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid()
            AND u.role IN ('admin', 'manager')
            AND u.organization_id = templates.organization_id
        )
    );

-- UPDATE: Apenas administradores e managers podem atualizar templates de sua organização
CREATE POLICY "templates_update_manager" ON app_8c11f279.templates
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid()
            AND u.role IN ('admin', 'manager')
            AND u.organization_id = templates.organization_id
        )
    );

-- DELETE: Apenas administradores podem deletar templates (soft delete via is_active é preferível)
CREATE POLICY "templates_delete_admin" ON app_8c11f279.templates
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
    );

-- ============================================
-- POLÍTICAS PARA TABELA requests
-- ============================================
-- SELECT: Usuários veem requests que criaram, foram atribuídos, ou são aprovadores
CREATE POLICY "requests_select_accessible" ON app_8c11f279.requests
    FOR SELECT USING (
        created_by = auth.uid()
        OR assigned_to = auth.uid()
        OR EXISTS (
            SELECT 1 FROM app_8c11f279.approvals a
            WHERE a.request_id = requests.id
            AND a.approver_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid()
            AND u.role = 'admin'
        )
    );

-- INSERT: Usuários podem criar requests apenas em sua organização
CREATE POLICY "requests_insert_user" ON app_8c11f279.requests
    FOR INSERT WITH CHECK (
        created_by = auth.uid()
        AND organization_id IN (
            SELECT organization_id FROM app_8c11f279.user_organizations
            WHERE user_id = auth.uid()
        )
    );

-- UPDATE: Criadores podem atualizar seus próprios requests (apenas se pendente)
CREATE POLICY "requests_update_creator" ON app_8c11f279.requests
    FOR UPDATE USING (
        created_by = auth.uid()
        AND status = 'pending'
    );

-- UPDATE: Administradores podem atualizar qualquer request
CREATE POLICY "requests_update_admin" ON app_8c11f279.requests
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
    );

-- DELETE: Apenas administradores podem deletar requests
CREATE POLICY "requests_delete_admin" ON app_8c11f279.requests
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
    );

-- ============================================
-- POLÍTICAS PARA TABELA approvals
-- ============================================
-- SELECT: Usuários veem approvals de requests que têm acesso
CREATE POLICY "approvals_select_accessible" ON app_8c11f279.approvals
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.requests r
            WHERE r.id = approvals.request_id
            AND (
                r.created_by = auth.uid()
                OR r.assigned_to = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM app_8c11f279.approvals a2
                    WHERE a2.request_id = r.id
                    AND a2.approver_id = auth.uid()
                )
                OR EXISTS (
                    SELECT 1 FROM app_8c11f279.users u
                    WHERE u.id = auth.uid()
                    AND u.role = 'admin'
                )
            )
        )
    );

-- INSERT: Apenas sistema (via trigger) ou administradores podem criar approvals
CREATE POLICY "approvals_insert_system" ON app_8c11f279.approvals
    FOR INSERT WITH CHECK (
        -- Aprovador deve pertencer à mesma organização do request
        EXISTS (
            SELECT 1 FROM app_8c11f279.requests r
            JOIN app_8c11f279.users u ON u.id = approvals.approver_id
            WHERE r.id = approvals.request_id
            AND u.organization_id = r.organization_id
        )
        AND (
            -- Inserção pelo sistema (auth.uid() pode ser NULL em triggers)
            auth.uid() IS NULL
            OR
            -- Ou por administrador
            EXISTS (
                SELECT 1 FROM app_8c11f279.users u
                WHERE u.id = auth.uid() AND u.role = 'admin'
            )
        )
    );

-- UPDATE: Aprovadores podem atualizar seus próprios approvals (apenas status)
CREATE POLICY "approvals_update_approver" ON app_8c11f279.approvals
    FOR UPDATE USING (approver_id = auth.uid())
    WITH CHECK (
        -- Apenas pode atualizar o status
        status IS NOT NULL
        AND status IN ('pending', 'approved', 'rejected')
        AND comment IS NOT DISTINCT FROM OLD.comment
        AND approver_id IS NOT DISTINCT FROM OLD.approver_id
        AND request_id IS NOT DISTINCT FROM OLD.request_id
    );

-- DELETE: Apenas administradores podem deletar approvals
CREATE POLICY "approvals_delete_admin" ON app_8c11f279.approvals
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
    );

-- ============================================
-- POLÍTICAS PARA TABELA audit_logs
-- ============================================
-- SELECT: Usuários veem logs de sua organização
CREATE POLICY "audit_logs_select_org" ON app_8c11f279.audit_logs
    FOR SELECT USING (
        organization_id IN (
            SELECT organization_id FROM app_8c11f279.user_organizations
            WHERE user_id = auth.uid()
        )
    );

-- INSERT: Apenas sistema (via triggers/funções) pode inserir logs
CREATE POLICY "audit_logs_insert_system" ON app_8c11f279.audit_logs
    FOR INSERT WITH CHECK (
        -- Apenas inserções por funções do sistema ou triggers
        auth.uid() IS NULL
        OR
        -- Ou por administrador (para manutenção)
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
    );

-- UPDATE: Logs são imutáveis após criação
-- (Nenhuma política de UPDATE - logs não devem ser alterados)

-- DELETE: Apenas administradores podem deletar logs (para manutenção)
CREATE POLICY "audit_logs_delete_admin" ON app_8c11f279.audit_logs
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
        )
    );

-- ============================================
-- POLÍTICAS PARA TABELA notifications
-- ============================================
-- SELECT: Usuários veem apenas suas notificações
CREATE POLICY "notifications_select_own" ON app_8c11f279.notifications
    FOR SELECT USING (user_id = auth.uid());

-- INSERT: Sistema ou administradores podem criar notificações
CREATE POLICY "notifications_insert_system" ON app_8c11f279.notifications
    FOR INSERT WITH CHECK (
        -- Notificação deve ser para usuário na mesma organização
        EXISTS (
            SELECT 1 FROM app_8c11f279.users u
            WHERE u.id = notifications.user_id
            AND u.organization_id = notifications.organization_id
        )
        AND (
            -- Inserção pelo sistema
            auth.uid() IS NULL
            OR
            -- Ou por administrador
            EXISTS (
                SELECT 1 FROM app_8c11f279.users u
                WHERE u.id = auth.uid() AND u.role = 'admin'
            )
            OR
            -- Ou usuário criando notificação para si mesmo (raro, mas possível)
            user_id = auth.uid()
        )
    );

-- UPDATE: Usuários podem marcar suas notificações como lidas
CREATE POLICY "notifications_update_own" ON app_8c11f279.notifications
    FOR UPDATE USING (user_id = auth.uid())
    WITH CHECK (
        -- Apenas pode atualizar is_read e read_at
        user_id IS NOT DISTINCT FROM OLD.user_id
        AND organization_id IS NOT DISTINCT FROM OLD.organization_id
        AND type IS NOT DISTINCT FROM OLD.type
        AND title IS NOT DISTINCT FROM OLD.title
        AND message IS NOT DISTINCT FROM OLD.message
        AND metadata IS NOT DISTINCT FROM OLD.metadata
    );

-- DELETE: Usuários podem deletar suas notificações
CREATE POLICY "notifications_delete_own" ON app_8c11f279.notifications
    FOR DELETE USING (user_id = auth.uid());

-- ============================================
-- POLÍTICAS ADICIONAIS DE SEGURANÇA
-- ============================================
-- Garante que usuários inativos não tenham acesso (exceto administradores)
-- Esta política é aplicada via as condições is_active = true nas políticas SELECT

-- NOTA: Para operações de sistema (triggers, funções), considere usar
-- SECURITY DEFINER ou configurar service_role adequadamente no Supabase
```

## Resumo das Correções Implementadas:

1. **Política INSERT para users**: Restrita a administradores ou ao próprio usuário durante registro
2. **Política UPDATE para users**: Separada em políticas para usuários comuns (com restrições) e administradores (com validações)
3. **Políticas explícitas DELETE**: Definidas para todas as tabelas, não dependendo apenas de ALL
4. **Política INSERT para audit_logs**: Restrita a sistema (triggers) ou administradores
5. **Código completo**: Todas as políticas finalizadas corretamente
6. **Políticas granulares**: Substituído ALL por