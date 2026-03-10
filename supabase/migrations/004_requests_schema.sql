```sql
-- ============================================
-- SCHEMA SQL PARA TABELAS DE REQUESTS E APPROVALS
-- Sistema: AxionOS
-- Módulo: Backend de Requests
-- Versão: 7.1 (Completa, Segura com RLS, Índices, Validações, Workflow e Triggers)
-- ============================================

-- 1. ENUMS NECESSÁRIOS (se ainda não existirem)
CREATE TYPE IF NOT EXISTS app_8c11f279.request_status AS ENUM (
    'draft',
    'pending',
    'in_review',
    'changes_requested',
    'approved',
    'rejected',
    'completed',
    'cancelled'
);

COMMENT ON TYPE app_8c11f279.request_status IS 'Estados possíveis de uma request no workflow';

CREATE TYPE IF NOT EXISTS app_8c11f279.approval_action AS ENUM (
    'approve',
    'reject',
    'request_changes'
);

COMMENT ON TYPE app_8c11f279.approval_action IS 'Ações possíveis em um processo de aprovação';

-- 2. TABELA DE WORKFLOW STEPS (para templates complexos)
CREATE TABLE IF NOT EXISTS app_8c11f279.workflow_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES app_8c11f279.templates(id) ON DELETE CASCADE,
    step_number INTEGER NOT NULL CHECK (step_number > 0),
    approver_role VARCHAR(100) NOT NULL,
    is_required BOOLEAN DEFAULT true,
    approval_threshold INTEGER DEFAULT 1 CHECK (approval_threshold >= 1),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(template_id, step_number)
);

COMMENT ON TABLE app_8c11f279.workflow_steps IS 'Define os passos do workflow para templates complexos';
COMMENT ON COLUMN app_8c11f279.workflow_steps.step_number IS 'Número sequencial do passo no workflow';
COMMENT ON COLUMN app_8c11f279.workflow_steps.approver_role IS 'Papel necessário para aprovar este passo';
COMMENT ON COLUMN app_8c11f279.workflow_steps.approval_threshold IS 'Número mínimo de aprovações necessárias neste passo';

-- 3. TABELA REQUESTS (ATUALIZADA)
CREATE TABLE IF NOT EXISTS app_8c11f279.requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES app_8c11f279.organizations(id) ON DELETE CASCADE,
    template_id UUID REFERENCES app_8c11f279.templates(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status app_8c11f279.request_status DEFAULT 'draft',
    previous_status app_8c11f279.request_status,
    priority VARCHAR(20) DEFAULT 'medium',
    due_date TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_by UUID NOT NULL REFERENCES app_8c11f279.users(id) ON DELETE CASCADE,
    assigned_to UUID REFERENCES app_8c11f279.users(id) ON DELETE SET NULL,
    completed_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints de validação (ATUALIZADAS)
    CONSTRAINT check_due_date_future 
        CHECK (due_date IS NULL OR due_date > created_at),
    CONSTRAINT check_completed_after_created 
        CHECK (completed_at IS NULL OR completed_at >= created_at),
    CONSTRAINT check_priority_values 
        CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    CONSTRAINT check_assigned_different_from_creator 
        CHECK (
            assigned_to IS NULL 
            OR assigned_to != created_by 
            OR (
                metadata->>'allow_self_assignment' IS NOT NULL 
                AND (metadata->>'allow_self_assignment')::boolean = true
            )
        ),
    CONSTRAINT check_completed_at_only_when_completed
        CHECK (completed_at IS NULL OR status = 'completed')
);

COMMENT ON TABLE app_8c11f279.requests IS 'Tabela principal de requests/solicitações';
COMMENT ON COLUMN app_8c11f279.requests.previous_status IS 'Status anterior (para rollback e auditoria)';
COMMENT ON COLUMN app_8c11f279.requests.priority IS 'Prioridade: low, medium, high, urgent';
COMMENT ON COLUMN app_8c11f279.requests.metadata IS 'Dados adicionais específicos do template';
COMMENT ON COLUMN app_8c11f279.requests.version IS 'Controle de concorrência (optimistic locking)';

-- 4. TABELA APPROVALS (ATUALIZADA COM REFERÊNCIA A WORKFLOW)
CREATE TABLE IF NOT EXISTS app_8c11f279.approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES app_8c11f279.requests(id) ON DELETE CASCADE,
    workflow_step_id UUID REFERENCES app_8c11f279.workflow_steps(id) ON DELETE SET NULL,
    approver_id UUID NOT NULL REFERENCES app_8c11f279.users(id) ON DELETE CASCADE,
    action app_8c11f279.approval_action,
    comments TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    step_number INTEGER NOT NULL,
    is_required BOOLEAN DEFAULT true,
    is_completed BOOLEAN DEFAULT false,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints (ATUALIZADAS)
    UNIQUE(request_id, approver_id, step_number),
    CONSTRAINT check_step_positive 
        CHECK (step_number > 0),
    CONSTRAINT check_action_requires_completion 
        CHECK (
            (action IS NULL AND is_completed = false) OR
            (action IS NOT NULL AND is_completed = true)
        ),
    CONSTRAINT check_completed_at_consistency 
        CHECK (
            (is_completed = false AND completed_at IS NULL) OR
            (is_completed = true AND completed_at IS NOT NULL)
        )
);

COMMENT ON TABLE app_8c11f279.approvals IS 'Registros de aprovações para cada request';
COMMENT ON COLUMN app_8c11f279.approvals.step_number IS 'Número do passo no workflow desta aprovação';
COMMENT ON COLUMN app_8c11f279.approvals.is_required IS 'Se esta aprovação é obrigatória para avançar';

-- 5. TABELA DE HISTÓRICO DE STATUS (para rastreabilidade completa)
CREATE TABLE IF NOT EXISTS app_8c11f279.request_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES app_8c11f279.requests(id) ON DELETE CASCADE,
    old_status app_8c11f279.request_status,
    new_status app_8c11f279.request_status NOT NULL,
    changed_by UUID NOT NULL REFERENCES app_8c11f279.users(id) ON DELETE CASCADE,
    reason TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT check_no_status_loop 
        CHECK (old_status IS DISTINCT FROM new_status)
);

COMMENT ON TABLE app_8c11f279.request_status_history IS 'Histórico completo de mudanças de status das requests';
COMMENT ON COLUMN app_8c11f279.request_status_history.reason IS 'Motivo da mudança de status (opcional)';

-- ============================================
-- FUNÇÕES AUXILIARES
-- ============================================

-- Função para atualizar a coluna updated_at automaticamente
CREATE OR REPLACE FUNCTION app_8c11f279.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Função para validar transições de status
CREATE OR REPLACE FUNCTION app_8c11f279.validate_status_transition(
    old_status app_8c11f279.request_status,
    new_status app_8c11f279.request_status
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Mapeamento de transições permitidas
    RETURN CASE
        -- Draft pode ir para qualquer estado exceto completed
        WHEN old_status = 'draft' THEN 
            new_status IN ('pending', 'in_review', 'changes_requested', 'approved', 'rejected', 'cancelled')
        
        -- Pending pode ser revisado, aprovado, rejeitado ou cancelado
        WHEN old_status = 'pending' THEN 
            new_status IN ('in_review', 'approved', 'rejected', 'cancelled')
        
        -- In_review pode ter mudanças solicitadas, ser aprovado ou rejeitado
        WHEN old_status = 'in_review' THEN 
            new_status IN ('changes_requested', 'approved', 'rejected')
        
        -- Changes_requested volta para in_review ou pode ser cancelado
        WHEN old_status = 'changes_requested' THEN 
            new_status IN ('in_review', 'cancelled')
        
        -- Approved pode ser completado ou (em casos raros) cancelado
        WHEN old_status = 'approved' THEN 
            new_status IN ('completed', 'cancelled')
        
        -- Rejected e Completed são estados finais (apenas admin pode reabrir)
        WHEN old_status IN ('rejected', 'completed') THEN 
            new_status IN ('draft') -- Reabertura como novo draft
        
        -- Cancelled pode ser reaberto como draft
        WHEN old_status = 'cancelled' THEN 
            new_status IN ('draft')
        
        ELSE FALSE
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Função para registrar histórico de status
CREATE OR REPLACE FUNCTION app_8c11f279.record_status_history()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO app_8c11f279.request_status_history (
            request_id,
            old_status,
            new_status,
            changed_by,
            metadata
        ) VALUES (
            NEW.id,
            OLD.status,
            NEW.status,
            COALESCE(
                current_setting('app.current_user_id', true)::uuid,
                NEW.created_by
            ),
            jsonb_build_object(
                'trigger', 'status_change',
                'old_version', OLD.version,
                'new_version', NEW.version
            )
        );
        
        -- Atualiza previous_status
        NEW.previous_status = OLD.status;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Função para validar transição de status com trigger
CREATE OR REPLACE FUNCTION app_8c11f279.validate_request_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Se o status está mudando, validar a transição
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        IF NOT app_8c11f279.validate_status_transition(OLD.status, NEW.status) THEN
            RAISE EXCEPTION 
                'Transição de status inválida: % -> %. Consulte a função validate_status_transition para transições permitidas.',
                OLD.status, NEW.status;
        END IF;
        
        -- Incrementar versão para controle de concorrência
        NEW.version = OLD.version + 1;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TRIGGERS
-- ============================================

-- Trigger para atualizar updated_at em requests
DROP TRIGGER IF EXISTS update_requests_updated_at ON app_8c11f279.requests;
CREATE TRIGGER update_requests_updated_at
    BEFORE UPDATE ON app_8c11f279.requests
    FOR EACH ROW
    EXECUTE FUNCTION app_8c11f279.update_updated_at_column();

-- Trigger para atualizar updated_at em approvals
DROP TRIGGER IF EXISTS update_approvals_updated_at ON app_8c11f279.approvals;
CREATE TRIGGER update_approvals_updated_at
    BEFORE UPDATE ON app_8c11f279.approvals
    FOR EACH ROW
    EXECUTE FUNCTION app_8c11f279.update_updated_at_column();

-- Trigger para atualizar updated_at em workflow_steps
DROP TRIGGER IF EXISTS update_workflow_steps_updated_at ON app_8c11f279.workflow_steps;
CREATE TRIGGER update_workflow_steps_updated_at
    BEFORE UPDATE ON app_8c11f279.workflow_steps
    FOR EACH ROW
    EXECUTE FUNCTION app_8c11f279.update_updated_at_column();

-- Trigger para validar status e registrar histórico
DROP TRIGGER IF EXISTS validate_and_record_status ON app_8c11f279.requests;
CREATE TRIGGER validate_and_record_status
    BEFORE UPDATE ON app_8c11f279.requests
    FOR EACH ROW
    EXECUTE FUNCTION app_8c11f279.validate_request_status();

-- Trigger para registrar histórico após validação
DROP TRIGGER IF EXISTS record_status_history_trigger ON app_8c11f279.requests;
CREATE TRIGGER record_status_history_trigger
    AFTER UPDATE OF status ON app_8c11f279.requests
    FOR EACH ROW
    EXECUTE FUNCTION app_8c11f279.record_status_history();

-- ============================================
-- POLÍTICAS RLS (ROW LEVEL SECURITY)
-- ============================================

-- Ativar RLS em todas as tabelas
ALTER TABLE app_8c11f279.requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_8c11f279.approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_8c11f279.workflow_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_8c11f279.request_status_history ENABLE ROW LEVEL SECURITY;

-- Políticas para tabela REQUESTS
DROP POLICY IF EXISTS requests_select_policy ON app_8c11f279.requests;
CREATE POLICY requests_select_policy ON app_8c11f279.requests
    FOR SELECT USING (
        -- Usuários podem ver requests da sua organização
        organization_id IN (
            SELECT organization_id 
            FROM app_8c11f279.user_organizations 
            WHERE user_id = current_setting('app.current_user_id', true)::uuid
        )
    );

DROP POLICY IF EXISTS requests_insert_policy ON app_8c11f279.requests;
CREATE POLICY requests_insert_policy ON app_8c11f279.requests
    FOR INSERT WITH CHECK (
        -- Usuários podem criar requests na sua organização
        organization_id IN (
            SELECT organization_id 
            FROM app_8c11f279.user_organizations 
            WHERE user_id = current_setting('app.current_user_id', true)::uuid
        )
        AND created_by = current_setting('app.current_user_id', true)::uuid
    );

DROP POLICY IF EXISTS requests_update_policy ON app_8c11f279.requests;
CREATE POLICY requests_update_policy ON app_8c11f279.requests
    FOR UPDATE USING (
        -- Criador pode editar drafts, atribuídos podem editar requests atribuídas a eles
        (
            created_by = current_setting('app.current_user_id', true)::uuid 
            AND status = 'draft'
        )
        OR
        (
            assigned_to = current_setting('app.current_user_id', true)::uuid
            AND status IN ('pending', 'in_review', 'changes_requested')
        )
        OR
        -- Admins podem editar qualquer request da organização
        EXISTS (
            SELECT 1 FROM app_8c11f279.user_organizations uo
            WHERE uo.user_id = current_setting('app.current_user_id', true)::uuid
            AND uo.organization_id = requests.organization_id
            AND uo.role = 'admin'
        )
    );

DROP POLICY IF EXISTS requests_delete_policy ON app_8c11f279.requests;
CREATE POLICY requests_delete_policy ON app_8c11f279.requests
    FOR DELETE USING (
        -- Apenas admins podem deletar requests
        EXISTS (
            SELECT 1 FROM app_8c11f279.user_organizations uo
            WHERE uo.user_id = current_setting('app.current_user_id', true)::uuid
            AND uo.organization_id = requests.organization_id
            AND uo.role = 'admin'
        )
        AND status = 'draft' -- Apenas drafts podem ser deletados
    );

-- Políticas para tabela APPROVALS
DROP POLICY IF EXISTS approvals_select_policy ON app_8c11f279.approvals;
CREATE POLICY approvals_select_policy ON app_8c11f279.approvals
    FOR SELECT USING (
        -- Usuários podem ver aprovações de requests que podem ver
        request_id IN (
            SELECT id FROM app_8c11f279.requests
            WHERE organization_id IN (
                SELECT organization_id 
                FROM app_8c11f279.user_organizations 
                WHERE user_id = current_setting('app.current_user_id', true)::uuid
            )
        )
    );

DROP POLICY IF EXISTS approvals_insert_policy ON app_8c11f279.approvals;
CREATE POLICY approvals_insert_policy ON app_8c11f279.approvals
    FOR INSERT WITH CHECK (
        -- Apenas sistema ou admins podem inserir aprovações
        EXISTS (
            SELECT 1 FROM app_8c11f279.user_organizations uo
            WHERE uo.user_id = current_setting('app.current_user_id', true)::uuid
            AND uo.organization_id = (
                SELECT organization_id 
                FROM app_8c11f279.requests 
                WHERE id = request_id