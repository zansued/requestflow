```sql
-- Schema SQL para tabela de templates - Versão Corrigida e Completa
-- Sistema: AxionOS
-- Módulo: Gerenciamento de Templates de Request
-- Data: 2024-01-15
-- Status: Revisado e Corrigido

-- =============================================
-- 1. TIPO ENUMERADO PARA TIPOS DE TEMPLATE
-- =============================================
CREATE TYPE app_8c11f279.template_type AS ENUM (
  'vacation_request',
  'purchase_order',
  'expense_report',
  'equipment_request',
  'access_request',
  'custom'
);

COMMENT ON TYPE app_8c11f279.template_type IS 'Tipos de templates disponíveis no sistema';

-- =============================================
-- 2. TABELA PRINCIPAL DE TEMPLATES
-- =============================================
CREATE TABLE IF NOT EXISTS app_8c11f279.templates (
  -- Identificação
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  
  -- Metadados do Template
  name VARCHAR(255) NOT NULL,
  description TEXT,
  type app_8c11f279.template_type NOT NULL DEFAULT 'custom',
  
  -- Configurações
  schema JSONB NOT NULL DEFAULT '{}'::jsonb,
  workflow_config JSONB NOT NULL DEFAULT '{}'::jsonb,
  
  -- Controle de Estado
  is_active BOOLEAN NOT NULL DEFAULT true,
  version INTEGER NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ, -- Campo para soft delete
  
  -- Metadados de Auditoria
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by UUID,
  
  -- Constraints de Integridade Referencial
  CONSTRAINT fk_templates_organization
    FOREIGN KEY (organization_id)
    REFERENCES app_8c11f279.organizations(id)
    ON DELETE RESTRICT,
  
  CONSTRAINT fk_template_created_by
    FOREIGN KEY (created_by)
    REFERENCES app_8c11f279.users(id)
    ON DELETE RESTRICT,
  
  CONSTRAINT fk_template_updated_by
    FOREIGN KEY (updated_by)
    REFERENCES app_8c11f279.users(id)
    ON DELETE SET NULL,
  
  -- Constraints de Validação (simplificadas para mensagens de erro mais claras)
  CONSTRAINT templates_schema_valid_json
    CHECK (
      schema IS NOT NULL 
      AND jsonb_typeof(schema) = 'object'
    ),
    
  CONSTRAINT templates_workflow_valid_json
    CHECK (
      workflow_config IS NOT NULL 
      AND jsonb_typeof(workflow_config) = 'object'
    ),
    
  CONSTRAINT templates_version_positive
    CHECK (version > 0),
    
  CONSTRAINT templates_name_not_empty
    CHECK (name !~ '^\s*$'),
    
  -- Constraint ajustada para permitir reativação de templates
  CONSTRAINT templates_deletion_consistency
    CHECK (
      (deleted_at IS NULL) OR
      (deleted_at IS NOT NULL AND is_active = false)
    ),
  
  -- Constraint de Unicidade para versões ativas (excluindo registros deletados)
  CONSTRAINT templates_name_org_version_unique
    UNIQUE (name, organization_id, version) 
    WHERE deleted_at IS NULL,
  
  -- Nova constraint: unicidade para templates ativos por nome e organização
  CONSTRAINT templates_name_org_active_unique
    UNIQUE (name, organization_id) 
    WHERE deleted_at IS NULL AND is_active = true
);

-- Comentários para campos JSONB
COMMENT ON COLUMN app_8c11f279.templates.schema IS 'Estrutura JSON do template contendo definição de campos, validações e configurações de UI. Máximo 200 campos.';
COMMENT ON COLUMN app_8c11f279.templates.workflow_config IS 'Configuração do fluxo de aprovação em JSON, incluindo estágios, aprovadores e condições. Máximo 100 etapas.';
COMMENT ON COLUMN app_8c11f279.templates.deleted_at IS 'Timestamp do soft delete. NULL significa que o registro está ativo';

-- Comentário sobre estratégia de versionamento
COMMENT ON TABLE app_8c11f279.templates IS '
Tabela de templates do sistema AxionOS.

ESTRATÉGIA DE VERSIONAMENTO:
- Cada template possui um número de versão incremental
- A constraint "templates_name_org_version_unique" garante unicidade por nome, organização e versão
- A constraint "templates_name_org_active_unique" garante que apenas um template ativo existe por nome e organização
- Para criar nova versão: inserir novo registro com version incrementado
- Para desativar versão anterior: atualizar is_active = false
- Histórico completo mantido para auditoria e rollback
';

-- =============================================
-- 3. ÍNDICES PARA OTIMIZAÇÃO DE CONSULTAS
-- =============================================

-- Índice para consultas por tipo de template
CREATE INDEX IF NOT EXISTS idx_templates_type 
ON app_8c11f279.templates(type) 
WHERE deleted_at IS NULL;

-- Índice para consultas por organização e status ativo
CREATE INDEX IF NOT EXISTS idx_templates_org_active 
ON app_8c11f279.templates(organization_id, is_active) 
WHERE deleted_at IS NULL;

-- Índice para consultas por criador
CREATE INDEX IF NOT EXISTS idx_templates_created_by 
ON app_8c11f279.templates(created_by) 
WHERE deleted_at IS NULL;

-- Índice para consultas por data de criação (para relatórios)
CREATE INDEX IF NOT EXISTS idx_templates_created_at 
ON app_8c11f279.templates(created_at DESC) 
WHERE deleted_at IS NULL;

-- Índice GIN para consultas em campos JSONB
CREATE INDEX IF NOT EXISTS idx_templates_schema_gin 
ON app_8c11f279.templates USING GIN (schema)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_templates_workflow_gin 
ON app_8c11f279.templates USING GIN (workflow_config)
WHERE deleted_at IS NULL;

-- =============================================
-- 4. TRIGGER PARA AUTO-ATUALIZAÇÃO DE updated_at
-- =============================================
CREATE OR REPLACE FUNCTION app_8c11f279.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_templates_updated_at
  BEFORE UPDATE ON app_8c11f279.templates
  FOR EACH ROW
  EXECUTE FUNCTION app_8c11f279.update_updated_at_column();

-- =============================================
-- 5. TRIGGER OTIMIZADO PARA VALIDAR CONSISTÊNCIA
-- =============================================
CREATE OR REPLACE FUNCTION app_8c11f279.validate_schema_workflow_consistency()
RETURNS TRIGGER AS $$
DECLARE
  required_fields JSONB;
  field_count INT;
  stage_count INT;
  field_elem JSONB;
  field_name TEXT;
  required_field TEXT;
  field_exists BOOLEAN;
BEGIN
  -- Validação de tamanho máximo do schema (200 campos)
  IF NEW.schema ? 'fields' THEN
    field_count := jsonb_array_length(NEW.schema->'fields');
    IF field_count > 200 THEN
      RAISE EXCEPTION 'O schema excede o limite máximo de 200 campos. Campos encontrados: %', field_count;
    END IF;
  END IF;

  -- Validação de tamanho máximo do workflow (100 etapas)
  IF NEW.workflow_config ? 'stages' THEN
    stage_count := jsonb_array_length(NEW.workflow_config->'stages');
    IF stage_count > 100 THEN
      RAISE EXCEPTION 'O workflow excede o limite máximo de 100 etapas. Etapas encontradas: %', stage_count;
    END IF;
  END IF;

  -- Validação otimizada de campos requeridos pelo workflow
  IF NEW.workflow_config ? 'requires_approval_fields' THEN
    required_fields := NEW.workflow_config->'requires_approval_fields';
    
    -- Verifica se required_fields é um array
    IF jsonb_typeof(required_fields) != 'array' THEN
      RAISE EXCEPTION 'O campo "requires_approval_fields" deve ser um array JSON';
    END IF;

    -- Cria uma tabela temporária em memória para campos existentes
    DROP TABLE IF EXISTS temp_existing_fields;
    CREATE TEMP TABLE temp_existing_fields (
      field_name TEXT PRIMARY KEY
    ) ON COMMIT DROP;

    -- Popula a tabela temporária com nomes de campos do schema
    IF NEW.schema ? 'fields' THEN
      FOR field_elem IN SELECT * FROM jsonb_array_elements(NEW.schema->'fields')
      LOOP
        IF field_elem ? 'name' THEN
          INSERT INTO temp_existing_fields (field_name) 
          VALUES (field_elem->>'name')
          ON CONFLICT DO NOTHING;
        END IF;
      END LOOP;
    END IF;

    -- Verifica cada campo requerido
    FOR required_field IN 
      SELECT jsonb_array_elements_text(required_fields)
    LOOP
      SELECT EXISTS (
        SELECT 1 FROM temp_existing_fields WHERE field_name = required_field
      ) INTO field_exists;
      
      IF NOT field_exists THEN
        RAISE EXCEPTION 'O campo "%" é requerido pelo workflow mas não está definido no schema', required_field;
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_template_consistency
  BEFORE INSERT OR UPDATE ON app_8c11f279.templates
  FOR EACH ROW
  EXECUTE FUNCTION app_8c11f279.validate_schema_workflow_consistency();

-- =============================================
-- 6. FUNÇÃO PARA VALIDAÇÃO DE SCHEMA JSON
-- =============================================
CREATE OR REPLACE FUNCTION app_8c11f279.validate_template_schema(
  p_schema JSONB,
  p_workflow_config JSONB DEFAULT '{}'::jsonb
)
RETURNS TABLE (
  is_valid BOOLEAN,
  error_message TEXT,
  field_count INT,
  stage_count INT
) AS $$
BEGIN
  -- Inicializa valores de retorno
  is_valid := true;
  error_message := NULL;
  field_count := 0;
  stage_count := 0;

  -- Valida estrutura básica do schema
  IF p_schema IS NULL OR jsonb_typeof(p_schema) != 'object' THEN
    is_valid := false;
    error_message := 'Schema deve ser um objeto JSON válido';
    RETURN NEXT;
    RETURN;
  END IF;

  -- Conta campos se existirem
  IF p_schema ? 'fields' THEN
    field_count := jsonb_array_length(p_schema->'fields');
    
    IF field_count > 200 THEN
      is_valid := false;
      error_message := format('Schema excede limite de 200 campos. Campos encontrados: %s', field_count);
      RETURN NEXT;
      RETURN;
    END IF;
  END IF;

  -- Valida workflow_config se fornecido
  IF p_workflow_config IS NOT NULL AND p_workflow_config::text != '{}' THEN
    IF jsonb_typeof(p_workflow_config) != 'object' THEN
      is_valid := false;
      error_message := 'Workflow config deve ser um objeto JSON válido';
      RETURN NEXT;
      RETURN;
    END IF;

    -- Conta estágios se existirem
    IF p_workflow_config ? 'stages' THEN
      stage_count := jsonb_array_length(p_workflow_config->'stages');
      
      IF stage_count > 100 THEN
        is_valid := false;
        error_message := format('Workflow excede limite de 100 etapas. Etapas encontradas: %s', stage_count);
        RETURN NEXT;
        RETURN;
      END IF;
    END IF;
  END IF;

  RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION app_8c11f279.validate_template_schema IS 'Valida a estrutura do schema e workflow config antes da inserção';

-- =============================================
-- 7. POLÍTICAS RLS (ROW LEVEL SECURITY)
-- =============================================
-- Nota: Descomente e adapte conforme necessário para seu ambiente Supabase/PostgreSQL

/*
-- Habilita RLS na tabela
ALTER TABLE app_8c11f279.templates ENABLE ROW LEVEL SECURITY;

-- Política para leitura: usuários podem ver templates de sua organização
CREATE POLICY templates_select_policy ON app_8c11f279.templates
  FOR SELECT USING (
    organization_id IN (
      SELECT organization_id 
      FROM app_8c11f279.user_organizations 
      WHERE user_id = current_user_id()
    )
    AND deleted_at IS NULL
  );

-- Política para inserção: usuários com permissão podem criar templates
CREATE POLICY templates_insert_policy ON app_8c11f279.templates
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 
      FROM app_8c11f279.user_roles ur
      JOIN app_8c11f279.roles r ON ur.role_id = r.id
      WHERE ur.user_id = current_user_id()
        AND ur.organization_id = organization_id
        AND r.permissions ? 'create_template'
    )
  );

-- Política para atualização: usuários com permissão podem atualizar templates
CREATE POLICY templates_update_policy ON app_8c11f279.templates
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 
      FROM app_8c11f279.user_roles ur
      JOIN app_8c11f279.roles r ON ur.role_id = r.id
      WHERE ur.user_id = current_user_id()
        AND ur.organization_id = organization_id
        AND r.permissions ? 'update_template'
    )
    AND deleted_at IS NULL
  );

-- Política para deleção (soft delete): usuários com permissão podem deletar
CREATE POLICY templates_delete_policy ON app_8c11f279.templates
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 
      FROM app_8c11f279.user_roles ur
      JOIN app_8c11f279.roles r ON ur.role_id = r.id
      WHERE ur.user_id = current_user_id()
        AND ur.organization_id = organization_id
        AND r.permissions ? 'delete_template'
    )
  );
*/

-- =============================================
-- 8. VIEW PARA TEMPLATES ATIVOS
-- =============================================
CREATE OR REPLACE VIEW app_8c11f279.active_templates AS
SELECT 
  id,
  organization_id,
  name,
  description,
  type,
  schema,
  workflow_config,
  version,
  created_by,
  created_at,
  updated_by,
  updated_at
FROM app_8c11f279.templates
WHERE deleted_at IS NULL 
  AND is_active = true;

COMMENT ON VIEW app_8c11f279.active_templates IS 'View para consulta de templates ativos (não deletados)';

-- =============================================
-- 9. FUNÇÃO PARA SOFT DELETE
-- =============================================
CREATE OR REPLACE FUNCTION app_8c11f279.soft_delete_template(
  p_template_id UUID,
  p_user_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_organization_id UUID;
  v_current_version INTEGER;
BEGIN
  -- Obtém organização e versão do template
  SELECT organization_id, version 
  INTO v_organization_id, v_current_version
  FROM app_8c11f279.templates 
  WHERE id = p_template_id 
    AND deleted_at IS NULL;
  
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Executa soft delete
  UPDATE app_8c11f279.templates
  SET 
    deleted_at = NOW(),
    is_active = false,
    updated_by = p_user_id,
    updated_at = NOW()
  WHERE id = p_template_id
    AND deleted_at IS NULL;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION app_8c11f279.soft_delete_template IS 'Realiza soft delete de um template, mantendo-o para histórico';

-- =============================================
-- 10. FUNÇÃO PARA CRIAR NOVA VERSÃO
-- =============================================
CREATE OR REPLACE FUNCTION app_8c11f279.create_template_version(
  p_template_id UUID,
  p_new_schema JSONB,
  p_new_workflow_config JSONB DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_user_id UUID
)
RETURNS UUID AS $$
DECLARE
  v_old_template RECORD;
  v_new_template_id UUID;
BEGIN
  -- Obtém dados do template atual
  SELECT *
  INTO v_old_template
  FROM app_8c11f279.templates
  WHERE id = p_template_id 
    AND deleted_at IS NULL
    AND is_active = true;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Template não encontrado ou não está ativo';
  END IF;

  -- Desativa versão anterior
  UPDATE app_8c11f279.templates
  SET is_active = false,
      updated_by = p_user_id,
      updated_at = NOW()
  WHERE id = p_template_id;

  -- Insere nova versão
  INSERT INTO app_8c11f279.templates (
    organization_id,
    name,
    description,
    type,
    schema,
    workflow_config,
    version,
    created_by,
    updated_by
  ) VALUES (
    v_old_template.organization_id,
    v_old_template.name,
    COALESCE(p_description, v_old_template.description),
    v_old_template.type,
    p_new_schema,
    COALESCE(p_new_workflow_config, v_old_template.workflow_config),
    v_old_template.version +