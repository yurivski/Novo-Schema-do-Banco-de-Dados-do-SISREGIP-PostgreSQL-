# Documentação do Banco de Dados - SISREGIP

## Sistema de Registro de Protocolos do Microfilme

**Desenvolvido por:** Yuri Pontes  
**Setor:** SAME - Hospital Central do Exército   
**SGBD:** PostgreSQL 16  
**Encoding:** UTF-8  

---

## Índice

- [Visão Geral](#visão-geral)
- [Estrutura do Banco](#estrutura-do-banco)
- [Tabelas](#tabelas)
  - [usuario](#tabela-usuario)
  - [recebedor](#tabela-recebedor)
  - [protocolo](#tabela-protocolo)
  - [auditoria_protocolo](#tabela-auditoria_protocolo)
- [Relacionamentos](#relacionamentos)
- [Índices](#índices)
- [Views](#views)
- [Triggers e Funções](#triggers-e-funções)
- [Dados Iniciais](#dados-iniciais)

---

## Visão Geral

O banco de dados `sistema_protocolos` foi desenvolvido para facilitar meu trabalho ao gerenciar o registro e controle de protocolos do microfilme no "SISREGIP" através de campos específicos no dashboard. O sistema implementa controles de auditoria automática e soft delete para preservação de dados.

### Características Principais:

- ✅ **Soft Delete**: Registros não são excluídos fisicamente
- ✅ **Auditoria Automática**: Todo INSERT/UPDATE/DELETE é registrado
- ✅ **Proteção de Dados**: Foreign Keys com RESTRICT
- ✅ **Performance Otimizada**: Índices em campos críticos
- ✅ **Timestamps Automáticos**: created_at e updated_at

---

## Estrutura do Banco

```
sistema_protocolos
│
├── 📁 Tabelas Principais
│   ├── usuario (solicitantes)
│   ├── recebedor (militares que recebem)
│   ├── protocolo (registro principal)
│   └── auditoria_protocolo (log de operações)
│
├── 📊 Views
│   ├── v_protocolos_ativos
│   └── v_auditoria_legivel
│
└── ⚙️ Funções e Triggers
    ├── registrar_auditoria()
    ├── atualizar_updated_at()
    └── triggers automáticos
```

---

## Tabelas

### Tabela: `usuario`

**Descrição:** Armazena os usuários que **SOLICITAM** os protocolos.

#### Estrutura:

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| `id` | SERIAL | PRIMARY KEY | Identificador único (auto-incremento) |
| `nome` | VARCHAR(200) | NOT NULL | Nome completo do usuário |
| `pmh` | VARCHAR(10) | UNIQUE | Número de prontuário militar |
| `ativo` | BOOLEAN | DEFAULT TRUE | Status do usuário (soft delete) |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Data de criação |
| `updated_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Última atualização |

#### Índices:

- `idx_usuario_nome` - Índice em `nome`
- `idx_usuario_pmh` - Índice em `pmh`
- `idx_usuario_ativo` - Índice em `ativo`

#### Exemplo de Dados:

```sql
INSERT INTO usuario (nome, pmh, ativo) VALUES
('Fulano da Silva', '123456', TRUE),
('Beltrano dos Santos', '234567', TRUE);
```

---

### Tabela: `recebedor`

**Descrição:** Registra os militares que **RECEBEM/RETIRAM** os protocolos na Secretaria do HCE.

#### Estrutura:

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| `id` | SERIAL | PRIMARY KEY | Identificador único |
| `nome` | VARCHAR(100) | NOT NULL | Nome e Guerra do militar |
| `pmh` | VARCHAR(10) | UNIQUE | PMH do militar |
| `ativo` | BOOLEAN | DEFAULT TRUE | Status ativo/inativo |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Data de criação |
| `updated_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Última atualização |

#### Índices:

- `idx_recebedor_nome` - Índice em `nome`
- `idx_recebedor_pmh` - Índice em `pmh`
- `idx_recebedor_ativo` - Índice em `ativo`

---

### Tabela: `protocolo`

**Descrição:** Tabela **PRINCIPAL** que registra todos os protocolos do sistema.

#### Estrutura:

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| `id` | SERIAL | PRIMARY KEY | Identificador único |
| `prot` | VARCHAR(20) | NOT NULL | Número do protocolo (ex: "1234") |
| `data_protocolo` | DATE | | Data de abertura do protocolo |
| `usuario_id` | INTEGER | FK → usuario(id) | Quem solicitou o protocolo |
| `pmh` | VARCHAR(10) | | PMH do solicitante |
| `recebedor_id` | INTEGER | FK → recebedor(id) | Quem recebeu na secretaria |
| `data_entrega` | DATE | | Data de entrega à secretaria |
| `observacoes` | TEXT | | Observações sobre o protocolo |
| `ativo` | BOOLEAN | DEFAULT TRUE | Status (soft delete) |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Data de criação |
| `updated_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Última atualização |
| `created_by` | VARCHAR(100) | | Quem criou o registro |
| `updated_by` | VARCHAR(100) | | Quem fez última modificação |

#### Foreign Keys:

```sql
protocolo.usuario_id → usuario.id (ON DELETE RESTRICT)
protocolo.recebedor_id → recebedor.id (ON DELETE RESTRICT)
```

**RESTRICT:** Impede a exclusão de usuário/recebedor se houver protocolos vinculados.

#### Índices:

- `idx_protocolo_prot` - Índice em `prot`
- `idx_protocolo_data` - Índice em `data_protocolo DESC`
- `idx_protocolo_ativo` - Índice em `ativo`
- `idx_protocolo_usuario` - Índice em `usuario_id`
- `idx_protocolo_recebedor` - Índice em `recebedor_id`

#### Exemplo de Dados:

```sql
INSERT INTO protocolo (prot, data_protocolo, usuario_id, pmh, data_entrega, recebedor_id)
VALUES ('1234', '2025-01-15', 1, '123456', '2025-01-20', 1);
```

---

### Tabela: `auditoria_protocolo`

**Descrição:** Registra **automaticamente** todas as operações (INSERT, UPDATE, DELETE) realizadas na tabela `protocolo`.

#### Estrutura:

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| `id` | SERIAL | PRIMARY KEY | Identificador único da auditoria |
| `protocolo_id` | INTEGER | | ID do protocolo modificado |
| `operacao` | VARCHAR(10) | NOT NULL | Tipo: 'INSERT', 'UPDATE', 'DELETE' |
| `dados_antigos` | JSONB | | Estado ANTES da modificação |
| `dados_novos` | JSONB | | Estado DEPOIS da modificação |
| `usuario` | VARCHAR(100) | | Quem executou a operação |
| `data_operacao` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Quando ocorreu |

#### Índices:

- `idx_auditoria_protocolo_id` - Índice em `protocolo_id`
- `idx_auditoria_data` - Índice em `data_operacao DESC`
- `idx_auditoria_operacao` - Índice em `operacao`

#### Regras de Preenchimento:

| Operação | dados_antigos | dados_novos |
|----------|---------------|-------------|
| INSERT | NULL | JSON do registro novo |
| UPDATE | JSON antes | JSON depois |
| DELETE | JSON do registro | NULL |

#### Exemplo de Registro:

```json
{
  "id": 1,
  "protocolo_id": 100,
  "operacao": "UPDATE",
  "dados_antigos": {"prot": "1234", "data_entrega": null},
  "dados_novos": {"prot": "1234", "data_entrega": "2025-01-20"},
  "usuario": "postgres",
  "data_operacao": "2025-01-20 14:30:00"
}
```

---

## 🔗 Relacionamentos

### Diagrama Entidade-Relacionamento:

```
┌─────────────┐
│   usuario   │
│─────────────│
│ id (PK)     │───┐
│ nome        │   │
│ pmh         │   │
│ ativo       │   │
└─────────────┘   │             
                  │             
                  │ 1:N         
                  │             
                  ▼             
┌─────────────────────────┐     
│      protocolo          │     
│─────────────────────────│     
│ id (PK)                 │     
│ prot                    │     
│ data_protocolo          │     
│ usuario_id (FK)         │
│ recebedor_id (FK)       │◄────┐
│ data_entrega            │     │
│ observacoes             │     │
│ ativo                   │     │
└─────────────────────────┘     │
                                │
                                │ 1:N
                                │
                  ┌─────────────┘
                  │
┌─────────────┐   │
│  recebedor  │   │
│─────────────│   │
│ id (PK)     │───┘
│ nome        │
│ pmh         │
│ ativo       │
└─────────────┘
```

### Regras de Negócio:

1. **Um usuário** pode solicitar **vários protocolos**
2. **Um recebedor** pode retirar **vários protocolos**
3. **Um protocolo** tem **um solicitante** e **um recebedor**
4. Não é possível excluir usuário/recebedor com protocolos vinculados (RESTRICT)

---

## Índices

### Propósito dos Índices:

| Índice | Coluna | Propósito |
|--------|--------|-----------|
| `idx_usuario_nome` | usuario.nome | Busca por nome do solicitante |
| `idx_usuario_pmh` | usuario.pmh | Busca por PMH |
| `idx_recebedor_nome` | recebedor.nome | Busca por nome do recebedor |
| `idx_protocolo_prot` | protocolo.prot | Busca por número do protocolo |
| `idx_protocolo_data` | protocolo.data_protocolo DESC | Listagem ordenada (mais recentes primeiro) |
| `idx_protocolo_ativo` | protocolo.ativo | Filtrar protocolos ativos (soft delete) |
| `idx_protocolo_usuario` | protocolo.usuario_id | Buscar protocolos por solicitante |
| `idx_protocolo_recebedor` | protocolo.recebedor_id | Buscar protocolos por recebedor |

---

## Views

### View: `v_protocolos_ativos`

**Descrição:** Exibe todos os protocolos ativos com informações completas (JOIN com usuários e recebedores).

#### Colunas:

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INTEGER | ID do protocolo |
| `numero` | VARCHAR(20) | Número do protocolo |
| `data_protocolo` | DATE | Data de abertura |
| `data_entrega` | DATE | Data de entrega |
| `solicitante` | VARCHAR(200) | Nome do solicitante |
| `pmh_solicitante` | VARCHAR(10) | PMH do solicitante |
| `recebedor` | VARCHAR(100) | Nome do recebedor |
| `pmh_recebedor` | VARCHAR(10) | PMH do recebedor |
| `observacoes` | TEXT | Observações |
| `entregue` | BOOLEAN | TRUE se foi entregue |
| `dias_espera` | INTEGER | Dias entre abertura e entrega |
| `created_at` | TIMESTAMP | Data de criação |
| `updated_at` | TIMESTAMP | Última atualização |
| `created_by` | VARCHAR(100) | Criado por |
| `updated_by` | VARCHAR(100) | Atualizado por |

#### Exemplo de Uso:

```sql
-- Listar todos os protocolos ativos
SELECT * FROM v_protocolos_ativos;

-- Protocolos pendentes de entrega
SELECT * FROM v_protocolos_ativos WHERE entregue = FALSE;

-- Protocolos com mais de 5 dias de espera
SELECT * FROM v_protocolos_ativos WHERE dias_espera > 5;
```

---

### View: `v_auditoria_legivel`

**Descrição:** Histórico de auditoria em formato legível.

#### Colunas:

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INTEGER | ID da auditoria |
| `protocolo_id` | INTEGER | ID do protocolo |
| `numero_protocolo` | VARCHAR(20) | Número do protocolo |
| `operacao` | VARCHAR(10) | INSERT/UPDATE/DELETE |
| `acao` | TEXT | Criou/Editou/Excluiu |
| `usuario` | VARCHAR(100) | Quem fez a operação |
| `data_operacao` | TIMESTAMP | Quando ocorreu |

#### Exemplo de Uso:

```sql
-- Ver últimas 10 operações
SELECT * FROM v_auditoria_legivel LIMIT 10;

-- Ver histórico de um protocolo específico
SELECT * FROM v_auditoria_legivel WHERE protocolo_id = 100;

-- Ver operações de hoje
SELECT * FROM v_auditoria_legivel 
WHERE DATE(data_operacao) = CURRENT_DATE;
```

---

## Triggers e Funções

### Função: `registrar_auditoria()`

**Descrição:** Registra automaticamente todas as operações na tabela `protocolo`.

**Tipo:** Trigger Function  
**Linguagem:** PL/pgSQL  
**Evento:** AFTER INSERT OR UPDATE OR DELETE  

#### Lógica:

1. **DELETE**: Guarda dados antigos em `auditoria_protocolo`
2. **UPDATE**: Guarda dados antes e depois
3. **INSERT**: Guarda dados do novo registro

#### Código Simplificado:

```sql
CREATE OR REPLACE FUNCTION registrar_auditoria()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria_protocolo (protocolo_id, operacao, dados_antigos)
        VALUES (OLD.id, 'DELETE', row_to_json(OLD));
        
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria_protocolo (protocolo_id, operacao, dados_antigos, dados_novos)
        VALUES (NEW.id, 'UPDATE', row_to_json(OLD), row_to_json(NEW));
        NEW.updated_at = CURRENT_TIMESTAMP;
        
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria_protocolo (protocolo_id, operacao, dados_novos)
        VALUES (NEW.id, 'INSERT', row_to_json(NEW));
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

### Função: `atualizar_updated_at()`

**Descrição:** Atualiza automaticamente o campo `updated_at` em qualquer UPDATE.

**Tipo:** Trigger Function  
**Linguagem:** PL/pgSQL  
**Evento:** BEFORE UPDATE  

#### Aplicada em:

- `usuario`
- `recebedor`
- `protocolo` (via `registrar_auditoria()`)

---

### Triggers Ativos:

| Trigger | Tabela | Evento | Função |
|---------|--------|--------|--------|
| `trigger_auditoria_protocolo` | protocolo | AFTER INSERT/UPDATE/DELETE | `registrar_auditoria()` |
| `trigger_atualizar_updated_at_usuario` | usuario | BEFORE UPDATE | `atualizar_updated_at()` |
| `trigger_atualizar_updated_at_recebedor` | recebedor | BEFORE UPDATE | `atualizar_updated_at()` |

---

## Dados Iniciais

### Usuários Padrão:

```sql
INSERT INTO usuario (nome, pmh, ativo) VALUES
('SISTEMA', '00000', TRUE),
('USUÁRIO TESTE', '12345', TRUE);
```

### Recebedores Padrão:

```sql
INSERT INTO recebedor (nome, pmh, ativo) VALUES
('SISTEMA', '00000', TRUE),
('RECEBEDOR TESTE', '67890', TRUE);
```

---

## Estatísticas do Banco

### Resumo:

- **Tabelas:** 4
- **Views:** 2
- **Triggers:** 3
- **Funções:** 2
- **Índices:** 14

### Verificação:

```sql
-- Ver todas as tabelas
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

-- Ver todas as views
SELECT table_name FROM information_schema.views 
WHERE table_schema = 'public';

-- Ver todos os triggers
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_schema = 'public';
```

---

## Segurança

### Soft Delete:

Todos os registros usam o campo `ativo` para marcação lógica:
- `ativo = TRUE`: Registro ativo (visível)
- `ativo = FALSE`: Registro inativo (não aparece mas existe)

**Vantagem:** Possibilita recuperação de dados e mantém histórico completo.

### Proteção de Dados:

Foreign Keys com `ON DELETE RESTRICT` impedem exclusão acidental de dados com dependências.

### Auditoria Completa:

Todo INSERT, UPDATE e DELETE é registrado automaticamente com:
- Dados antes e depois
- Quem fez a operação
- Quando foi realizado

---

## Performance

### Otimizações Implementadas:

1. **Índices em campos frequentes** (prot, nome, pmh, datas, recebimento)
2. **Índices otimizados:**
- `protocolo.prot` (número do protocolo)
- `usuario.nome` (solicitante)
- `recebedor.nome` (exibido como "Recebimento" no dashboard)
- `usuario.pmh` (prontuário do solicitante)
- `protocolo.data_protocolo` e `protocolo.data_entrega`
3. **Índice DESC em datas** (mais recentes primeiro)
4. **Índices em Foreign Keys** (JOIN mais rápido)
5. **Views pré-calculadas** (JOINs prontos)

---

## Manutenção

### Comandos Úteis:

```sql
-- Ver tamanho do banco
SELECT pg_size_pretty(pg_database_size('sistema_protocolos'));

-- Ver tamanho das tabelas
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Vacuum completo (otimização)
VACUUM ANALYZE;

-- Reindexar todas as tabelas
REINDEX DATABASE sistema_protocolos;
```

---

## Suporte

**Desenvolvedor:** Yuri Pontes  
**Setor:** SAME - Serviço de Arquivo Médico e Estatística  

---

## ⚖️ Licença

Sistema não oficial desenvolvido para uso interno do setor (SAME) para facilitar o controle de protocolos recebidos e entregues pela seção (Microfilme).

