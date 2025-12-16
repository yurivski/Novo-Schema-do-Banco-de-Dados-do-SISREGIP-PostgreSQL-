-- Por Yuri Pontes
/* A criação desse banco de dados tem como objetivo facilitar meu trabalho ao 
    receber e dar saída nos protocolos para a Secretaria do HCE. Os dados são inseridos, deletados ou editados
    no "SISREGIP" através de campos específicos no dashboard. */

CREATE DATABASE sistema_protocolos
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8';

COMMENT ON DATABASE sistema_protocolos 
    IS 'Banco de dados do SISREGIP - Sistema de Registro de Protocolos do Microfilme';

-- Criação da tabela "usuario" para armazenar os usuários que SOLICITAM os protocolos
\c sistema_protocolos

CREATE TABLE usuario (
    id SERIAL PRIMARY KEY,
    -- SERIAL = INTEGER com auto-incremento
    -- PRIMARY KEY = Chave primária única
    
    nome VARCHAR(200) NOT NULL,
    -- Nome completo do usuário (obrigatório)
    
    pmh VARCHAR(10) UNIQUE,
    -- Número de prontuário do usuário
    
    ativo BOOLEAN DEFAULT TRUE,
    -- Status do usuário e "Soft delete" para não excluir o registro, apenas marca como inativo
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Data/hora de criação do registro (preenchido automaticamente)
    
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    -- Data/hora da última atualização (atualizado por trigger)
);

-- Índices para acilitar as buscas
CREATE INDEX idx_usuario_nome ON usuario(nome);
CREATE INDEX idx_usuario_pmh ON usuario(pmh);
CREATE INDEX idx_usuario_ativo ON usuario(ativo);

COMMENT ON TABLE usuario IS 'Usuários solicitantes de protocolos';
COMMENT ON COLUMN usuario.pmh IS 'Número de identificação militar';
COMMENT ON COLUMN usuario.ativo IS 'FALSE = usuário inativo (soft delete)';


-- Criação da abela "recebedor" para registrar o militar que recebeu o protocolo na secretaria

CREATE TABLE recebedor (
    id SERIAL PRIMARY KEY,
    -- ID único auto-incrementado
    
    nome VARCHAR(100) NOT NULL,
    -- Nome e Guerra do Militar que recebeu
    
    pmh VARCHAR(10) UNIQUE,
    -- PMH do usuario que solicitou a cópia
    
    ativo BOOLEAN DEFAULT TRUE,
    -- Status ativo/inativo
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Data de criação
    
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    -- Última atualização
);

CREATE INDEX idx_recebedor_nome ON recebedor(nome);
CREATE INDEX idx_recebedor_pmh ON recebedor(pmh);
CREATE INDEX idx_recebedor_ativo ON recebedor(ativo);

COMMENT ON TABLE recebedor IS 'Pessoas que recebem/retiram os protocolos';
COMMENT ON COLUMN recebedor.ativo IS 'FALSE = recebedor inativo (soft delete)';

-- Criação da tabela "Protocolo", tabela principal que registra todos os protocolos

CREATE TABLE protocolo (
    id SERIAL PRIMARY KEY,
    prot VARCHAR(20) NOT NULL,
    -- Número do protocolo (ex: "1234")
    -- NOT NULL = Obrigatório o preenchimento
    
    data_protocolo DATE,
    -- Data de bertura do protocolo
    
    usuario_id INTEGER, -- Relacionamento entre tabelas
    -- Quem SOLICITOU o protocolo (FK → usuario.id)
    
    pmh VARCHAR(10),
    -- PMH do solicitante
    
    recebedor_id INTEGER,
    -- ilitar que RECEBEU o protocolo na secretaria (FK → recebedor.id)

    data_entrega DATE,
    -- Quando o protocolo foi entregue à secretaria
    
    observacoes TEXT,
    -- Observações ou anotações sobre o protocolo
    
    ativo BOOLEAN DEFAULT TRUE,
    -- TRUE = ativo, FALSE = "deletado" (soft delete)
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Quando foi criado
    
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Última atualização
    
    created_by VARCHAR(100),
    -- Quem criou o registro
    
    updated_by VARCHAR(100)
    -- Quem fez a última modificação
);

-- Relacionamento entre tabelas com proteção:
ALTER TABLE protocolo
ADD CONSTRAINT protocolo_usuario_id_fkey 
    FOREIGN KEY (usuario_id) 
    REFERENCES usuario(id) 
    ON DELETE RESTRICT;
-- RESTRICT = Impede deletar usuário se houver protocolos vinculados
-- Protege contra exclusão acidental de dados importantes

ALTER TABLE protocolo
ADD CONSTRAINT protocolo_recebedor_id_fkey 
    FOREIGN KEY (recebedor_id) 
    REFERENCES recebedor(id) 
    ON DELETE RESTRICT;
-- RESTRICT = Impede deletar recebedor se houver protocolos vinculados

-- Índices para otimização de Performance:
-- Busca por número do protocolo (muito usado)
CREATE INDEX idx_protocolo_prot ON protocolo(prot);

-- Busca por data (ordenação decrescente = mais recentes primeiro)
CREATE INDEX idx_protocolo_data ON protocolo(data_protocolo DESC);

-- Filtrar apenas protocolos ativos (soft delete)
CREATE INDEX idx_protocolo_ativo ON protocolo(ativo);

-- Buscar protocolos por usuário
CREATE INDEX idx_protocolo_usuario ON protocolo(usuario_id);

-- Buscar protocolos por recebedor
CREATE INDEX idx_protocolo_recebedor ON protocolo(recebedor_id);

-- Criação da "Tabela de Auditoria": Registra TODAS as operações (INSERT, UPDATE, DELETE) automaticamente
CREATE TABLE auditoria_protocolo (
    id SERIAL PRIMARY KEY,
    -- ID único da auditoria
    
    protocolo_id INTEGER,
    -- ID do protocolo modificado
    
    operacao VARCHAR(10) NOT NULL,
    -- Tipo de operação: 'INSERT', 'UPDATE' ou 'DELETE'
    
    dados_antigos JSONB,
    -- Estado ANTES da modificação (JSON)
    -- NULL para INSERT (não havia dados antes)
    
    dados_novos JSONB,
    -- Estado DEPOIS da modificação (JSON)
    -- NULL para DELETE (registro foi removido)
    
    usuario VARCHAR(100),
    -- Quem fez a operação
    
    data_operacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    -- Quando a operação foi realizada
);

-- Índices para buscar na auditoria
CREATE INDEX idx_auditoria_protocolo_id ON auditoria_protocolo(protocolo_id);
CREATE INDEX idx_auditoria_data ON auditoria_protocolo(data_operacao DESC);
CREATE INDEX idx_auditoria_operacao ON auditoria_protocolo(operacao);

COMMENT ON TABLE auditoria_protocolo IS 'Log automático de todas as operações nos protocolos';
COMMENT ON COLUMN auditoria_protocolo.dados_antigos IS 'Estado do registro ANTES da modificação';
COMMENT ON COLUMN auditoria_protocolo.dados_novos IS 'Estado do registro DEPOIS da modificação';


-- Função para registrar auditoria rutomaticamente:
CREATE OR REPLACE FUNCTION registrar_auditoria()
RETURNS TRIGGER AS $$
-- Esta função é executada AUTOMATICAMENTE sempre que houver:
-- INSERT, UPDATE ou DELETE na tabela protocolo

BEGIN
    IF TG_OP = 'DELETE' THEN
        -- Quando o protocolo for Excluído
        INSERT INTO auditoria_protocolo (
            protocolo_id,
            operacao,
            dados_antigos,
            dados_novos,
            usuario,
            data_operacao
        ) VALUES (
            OLD.id,              -- ID do protocolo excluído
            'DELETE',
            row_to_json(OLD),    -- Dados que foram excluídos
            NULL,                -- Se não houver dados novos
            current_user,
            CURRENT_TIMESTAMP
        );
        RETURN OLD;
        
    ELSIF TG_OP = 'UPDATE' THEN
        -- Quando o protocolo for atualizado
        INSERT INTO auditoria_protocolo (
            protocolo_id,
            operacao,
            dados_antigos,
            dados_novos,
            usuario,
            data_operacao
        ) VALUES (
            NEW.id,
            'UPDATE',
            row_to_json(OLD),    -- Como estava ANTES
            row_to_json(NEW),    -- Como ficou DEPOIS
            current_user,
            CURRENT_TIMESTAMP
        );
        
        -- Atualizar campo updated_at automaticamente
        NEW.updated_at = CURRENT_TIMESTAMP;
        
        RETURN NEW;
        
    ELSIF TG_OP = 'INSERT' THEN
        -- Quando novo protocolo for inserido
        INSERT INTO auditoria_protocolo (
            protocolo_id,
            operacao,
            dados_antigos,
            dados_novos,
            usuario,
            data_operacao
        ) VALUES (
            NEW.id,
            'INSERT',
            NULL,                -- Não havia dados antes
            row_to_json(NEW),    -- Dados do novo protocolo
            current_user,
            CURRENT_TIMESTAMP
        );
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION registrar_auditoria() 
    IS 'Função que registra automaticamente todas as operações na tabela protocolo';

-- Triger para ativar auditoria automática

CREATE TRIGGER trigger_auditoria_protocolo
    AFTER INSERT OR UPDATE OR DELETE ON protocolo
    -- Executar DEPOIS da operação (para garantir que foi salva)
    FOR EACH ROW
    -- Uma vez para cada linha afetada
    EXECUTE FUNCTION registrar_auditoria();
    -- Chama a função criada acima

COMMENT ON TRIGGER trigger_auditoria_protocolo ON protocolo 
    IS 'Registra automaticamente INSERT, UPDATE e DELETE na tabela de auditoria';

-- Função para atualizar updated_at automaticamente

CREATE OR REPLACE FUNCTION atualizar_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    -- Sempre que houver UPDATE, atualiza o campo updated_at
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar em todas as tabelas com updated_at
CREATE TRIGGER trigger_atualizar_updated_at_usuario
    BEFORE UPDATE ON usuario
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_updated_at();

CREATE TRIGGER trigger_atualizar_updated_at_recebedor
    BEFORE UPDATE ON recebedor
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_updated_at();

-- View: Protocolos ativos com informações completas (JOIN com usuários e recebedores)
CREATE OR REPLACE VIEW v_protocolos_ativos AS
SELECT 
    p.id,
    p.prot AS numero,
    p.data_protocolo,
    p.data_entrega,
    u.nome AS solicitante,
    u.pmh AS pmh_solicitante,
    r.nome AS recebedor,
    r.pmh AS pmh_recebedor,
    p.observacoes,
    -- Calcula se foi entregue ou não
    CASE 
        WHEN p.data_entrega IS NOT NULL THEN TRUE 
        ELSE FALSE 
    END AS entregue,
    -- Calcula tempo de espera em dias
    CASE 
        WHEN p.data_entrega IS NOT NULL 
        THEN EXTRACT(DAY FROM (p.data_entrega - p.data_protocolo))
        ELSE EXTRACT(DAY FROM (CURRENT_DATE - p.data_protocolo))
    END AS dias_espera,
    p.created_at,
    p.updated_at,
    p.created_by,
    p.updated_by
FROM protocolo p
LEFT JOIN usuario u ON p.usuario_id = u.id
-- LEFT JOIN = Traz todos os protocolos mesmo sem usuário
LEFT JOIN recebedor r ON p.recebedor_id = r.id
-- LEFT JOIN = Traz todos os protocolos mesmo sem recebedor
WHERE p.ativo = TRUE
-- Mostra apenas protocolos ativos (não "deletados")
ORDER BY p.data_protocolo DESC;
-- Mais recentes primeiro

COMMENT ON VIEW v_protocolos_ativos 
    IS 'View com todos os protocolos ativos e informações relacionadas';

-- View: Histórico de Auditoria Legível
CREATE OR REPLACE VIEW v_auditoria_legivel AS
SELECT 
    a.id,
    a.protocolo_id,
    p.prot AS numero_protocolo,
    a.operacao,
    CASE 
        WHEN a.operacao = 'INSERT' THEN 'Criou'
        WHEN a.operacao = 'UPDATE' THEN 'Editou'
        WHEN a.operacao = 'DELETE' THEN 'Excluiu'
    END AS acao,
    a.usuario,
    a.data_operacao
FROM auditoria_protocolo a
LEFT JOIN protocolo p ON a.protocolo_id = p.id
ORDER BY a.data_operacao DESC;

COMMENT ON VIEW v_auditoria_legivel 
    IS 'Histórico de auditoria em formato legível';

-- Usuários padrão para testes
INSERT INTO usuario (nome, pmh, ativo) VALUES
('SISTEMA', '00000', TRUE),
('USUÁRIO TESTE', '12345', TRUE);

-- Recebedores padrão para testes
INSERT INTO recebedor (nome, pmh, ativo) VALUES
('SISTEMA', '00000', TRUE),
('RECEBEDOR TESTE', '67890', TRUE);

-- Permissões:
-- Conceder todas as permissões ao usuário postgres
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO postgres;

-- Verificação:
-- Mostrar todas as tabelas criadas
SELECT 
    'Tabelas criadas:' AS tipo,
    table_name AS nome
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Mostrar todas as views criadas
SELECT 
    'Views criadas:' AS tipo,
    table_name AS nome
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;

-- Mostrar todos os triggers
SELECT 
    'Triggers criados:' AS tipo,
    trigger_name AS nome,
    event_object_table AS tabela
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- Resumo:
SELECT 
    'Sistema criado com sucesso!' AS status,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE') AS tabelas,
    (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public') AS views,
    (SELECT COUNT(DISTINCT trigger_name) FROM information_schema.triggers WHERE trigger_schema = 'public') AS triggers;
