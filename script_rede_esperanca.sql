DROP DATABASE IF EXISTS rede_esperanca;

CREATE DATABASE IF NOT EXISTS rede_esperanca
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE rede_esperanca;


CREATE TABLE unidades (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nome        VARCHAR(150) NOT NULL UNIQUE,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE usuarios (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  unidade_id  BIGINT UNSIGNED NOT NULL,
  nome        VARCHAR(150) NOT NULL,
  email       VARCHAR(150) NOT NULL UNIQUE,
  papel       ENUM('coordenador','voluntario') NOT NULL DEFAULT 'voluntario',
  ativo       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (unidade_id) REFERENCES unidades(id)
);


CREATE TABLE familias (
  id                    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  unidade_id            BIGINT UNSIGNED NOT NULL,
  nome_responsavel      VARCHAR(150) NOT NULL,
  cpf                   CHAR(11) NOT NULL UNIQUE,            
  endereco              VARCHAR(255) NOT NULL,
  bairro                VARCHAR(100),
  num_pessoas           SMALLINT UNSIGNED NOT NULL,
  status                ENUM('aguardando_cesta','cesta_entregue','em_analise')
                        NOT NULL DEFAULT 'aguardando_cesta',
  observacoes           TEXT,                                 
  consentimento_lgpd_em DATETIME,
  ultima_entrega_em     DATETIME,
  created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT ck_familias_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
  CONSTRAINT ck_familias_pessoas CHECK (num_pessoas > 0),
  FOREIGN KEY (unidade_id) REFERENCES unidades(id),
  INDEX idx_familias_status (unidade_id, status),
  INDEX idx_familias_nome (nome_responsavel)
);

CREATE TABLE historico_status_familia (
  id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  familia_id       BIGINT UNSIGNED NOT NULL,
  status_anterior  ENUM('aguardando_cesta','cesta_entregue','em_analise'),
  status_novo      ENUM('aguardando_cesta','cesta_entregue','em_analise') NOT NULL,
  usuario_id       BIGINT UNSIGNED,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (familia_id) REFERENCES familias(id) ON DELETE CASCADE,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);


CREATE TABLE origens_doacao (
  id    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nome  VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE itens (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nome            VARCHAR(150) NOT NULL UNIQUE,             
  unidade_medida  VARCHAR(20) NOT NULL DEFAULT 'un',
  ativo           BOOLEAN NOT NULL DEFAULT TRUE
);


CREATE TABLE lotes_estoque (
  id                BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  unidade_id        BIGINT UNSIGNED NOT NULL,
  item_id           BIGINT UNSIGNED NOT NULL,
  origem_id         BIGINT UNSIGNED,
  validade          DATE,
  quantidade_atual  INT NOT NULL DEFAULT 0,
  recebido_em       DATE NOT NULL DEFAULT (CURRENT_DATE),
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT ck_lote_saldo CHECK (quantidade_atual >= 0),
  FOREIGN KEY (unidade_id) REFERENCES unidades(id),
  FOREIGN KEY (item_id)    REFERENCES itens(id),
  FOREIGN KEY (origem_id)  REFERENCES origens_doacao(id),
  INDEX idx_lotes_unidade_item (unidade_id, item_id)
);


CREATE TABLE cestas (                                         
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  unidade_id   BIGINT UNSIGNED NOT NULL,
  status       ENUM('disponivel','reservada','entregue','cancelada') NOT NULL DEFAULT 'disponivel',
  montada_em   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  montada_por  BIGINT UNSIGNED,
  FOREIGN KEY (unidade_id)  REFERENCES unidades(id),
  FOREIGN KEY (montada_por) REFERENCES usuarios(id)
);

CREATE TABLE cesta_itens (
  cesta_id    BIGINT UNSIGNED NOT NULL,
  lote_id     BIGINT UNSIGNED NOT NULL,
  quantidade  INT NOT NULL,
  PRIMARY KEY (cesta_id, lote_id),
  CONSTRAINT ck_cesta_itens_qtd CHECK (quantidade > 0),
  FOREIGN KEY (cesta_id) REFERENCES cestas(id) ON DELETE CASCADE,
  FOREIGN KEY (lote_id)  REFERENCES lotes_estoque(id)
);


CREATE TABLE movimentacoes_estoque (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  lote_id     BIGINT UNSIGNED NOT NULL,
  tipo        ENUM('entrada','saida','ajuste') NOT NULL,
  delta       INT NOT NULL,                                     
  motivo      VARCHAR(255),
  cesta_id    BIGINT UNSIGNED,                                 
  usuario_id  BIGINT UNSIGNED,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT ck_mov_delta CHECK (delta <> 0),
  FOREIGN KEY (lote_id)    REFERENCES lotes_estoque(id),
  FOREIGN KEY (cesta_id)   REFERENCES cestas(id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);

CREATE TABLE agendamentos (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  familia_id     BIGINT UNSIGNED NOT NULL,
  cesta_id       BIGINT UNSIGNED NOT NULL,
  data_hora      DATETIME NOT NULL,
  tipo           ENUM('retirada_centro','entrega_domiciliar') NOT NULL DEFAULT 'retirada_centro',
  status         ENUM('agendado','concluido','cancelado','nao_compareceu') NOT NULL DEFAULT 'agendado',
  observacoes    TEXT,
  criado_por     BIGINT UNSIGNED,
  concluido_em   DATETIME,
  concluido_por  BIGINT UNSIGNED,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  cesta_ativa    BIGINT UNSIGNED GENERATED ALWAYS AS
                 (IF(status IN ('agendado','concluido'), cesta_id, NULL)) STORED,
  UNIQUE KEY uq_agendamento_cesta (cesta_ativa),
  FOREIGN KEY (familia_id)    REFERENCES familias(id),
  FOREIGN KEY (cesta_id)      REFERENCES cestas(id),
  FOREIGN KEY (criado_por)    REFERENCES usuarios(id),
  FOREIGN KEY (concluido_por) REFERENCES usuarios(id),
  INDEX idx_agendamentos_data (data_hora)
);


CREATE TABLE campanhas (
  id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  unidade_id       BIGINT UNSIGNED NOT NULL,
  titulo           VARCHAR(200) NOT NULL,
  descricao        TEXT,
  proxima_entrega  DATE,
  ativa            BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (unidade_id) REFERENCES unidades(id)
);

CREATE TABLE metas_mensais (
  unidade_id     BIGINT UNSIGNED NOT NULL,
  mes            DATE NOT NULL,                                 
  meta_entregas  INT NOT NULL,
  PRIMARY KEY (unidade_id, mes),
  CONSTRAINT ck_meta CHECK (meta_entregas > 0),
  FOREIGN KEY (unidade_id) REFERENCES unidades(id)
);


DELIMITER $$

CREATE TRIGGER familia_before_update BEFORE UPDATE ON familias
FOR EACH ROW
BEGIN
  IF NOT (NEW.status <=> OLD.status) THEN
    INSERT INTO historico_status_familia(familia_id, status_anterior, status_novo)
    VALUES (NEW.id, OLD.status, NEW.status);
  END IF;
END$$

CREATE TRIGGER movimentacao_after_insert AFTER INSERT ON movimentacoes_estoque
FOR EACH ROW
BEGIN
  UPDATE lotes_estoque
     SET quantidade_atual = quantidade_atual + NEW.delta
   WHERE id = NEW.lote_id;
END$$

CREATE PROCEDURE agendar_entrega(
  IN  p_familia   BIGINT UNSIGNED,
  IN  p_cesta     BIGINT UNSIGNED,
  IN  p_data_hora DATETIME,
  IN  p_tipo      VARCHAR(30),
  IN  p_usuario   BIGINT UNSIGNED,
  OUT p_id        BIGINT UNSIGNED
)
BEGIN
  START TRANSACTION;
  UPDATE cestas SET status = 'reservada' WHERE id = p_cesta AND status = 'disponivel';
  IF ROW_COUNT() = 0 THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A cesta informada não está disponível';
  END IF;
  INSERT INTO agendamentos(familia_id, cesta_id, data_hora, tipo, criado_por)
  VALUES (p_familia, p_cesta, p_data_hora, p_tipo, p_usuario);
  SET p_id = LAST_INSERT_ID();
  COMMIT;
END$$

CREATE PROCEDURE confirmar_entrega(IN p_agendamento BIGINT UNSIGNED, IN p_usuario BIGINT UNSIGNED)
BEGIN
  DECLARE v_familia BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_cesta   BIGINT UNSIGNED DEFAULT NULL;
  START TRANSACTION;
  SELECT familia_id, cesta_id INTO v_familia, v_cesta
    FROM agendamentos WHERE id = p_agendamento AND status = 'agendado' FOR UPDATE;
  IF v_cesta IS NULL THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O agendamento não está pendente';
  END IF;
  UPDATE agendamentos SET status = 'concluido', concluido_em = NOW(), concluido_por = p_usuario
   WHERE id = p_agendamento;
  UPDATE cestas   SET status = 'entregue' WHERE id = v_cesta;
  UPDATE familias SET status = 'cesta_entregue', ultima_entrega_em = NOW() WHERE id = v_familia;
  COMMIT;
END$$

CREATE PROCEDURE cancelar_agendamento(IN p_agendamento BIGINT UNSIGNED)
BEGIN
  DECLARE v_cesta BIGINT UNSIGNED DEFAULT NULL;
  START TRANSACTION;
  SELECT cesta_id INTO v_cesta
    FROM agendamentos WHERE id = p_agendamento AND status = 'agendado' FOR UPDATE;
  IF v_cesta IS NULL THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O agendamento não está pendente';
  END IF;
  UPDATE agendamentos SET status = 'cancelado' WHERE id = p_agendamento;
  UPDATE cestas SET status = 'disponivel' WHERE id = v_cesta;
  COMMIT;
END$$

DELIMITER ;



CREATE VIEW v_dashboard_kpis AS
SELECT u.id AS unidade_id,
  (SELECT COUNT(*) FROM cestas c WHERE c.unidade_id = u.id AND c.status = 'disponivel')           AS cestas_disponiveis,
  (SELECT COUNT(*) FROM familias f WHERE f.unidade_id = u.id)                                     AS familias_cadastradas,
  (SELECT COUNT(*) FROM familias f WHERE f.unidade_id = u.id AND f.status = 'aguardando_cesta')   AS aguardando_cesta,
  (SELECT COUNT(*) FROM agendamentos a JOIN familias f ON f.id = a.familia_id
    WHERE f.unidade_id = u.id AND a.status = 'concluido')                                         AS entregas_realizadas
FROM unidades u;


CREATE VIEW v_status_familias AS
SELECT unidade_id, status, COUNT(*) AS qtd,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY unidade_id)) AS percentual
FROM familias
GROUP BY unidade_id, status;

CREATE VIEW v_estoque_cards AS
SELECT l.id AS lote_id, l.unidade_id, i.nome AS item, o.nome AS origem,
       l.validade, l.quantidade_atual,
       CASE WHEN l.quantidade_atual = 0 THEN 'esgotado'
            WHEN l.validade < CURDATE() THEN 'vencido'
            ELSE 'ativo' END AS situacao
FROM lotes_estoque l
JOIN itens i ON i.id = l.item_id
LEFT JOIN origens_doacao o ON o.id = l.origem_id;


CREATE VIEW v_agendamentos AS
SELECT a.id, f.unidade_id, f.nome_responsavel, a.data_hora, a.tipo, a.cesta_id, a.status
FROM agendamentos a
JOIN familias f ON f.id = a.familia_id;


INSERT INTO unidades(nome) VALUES ('Unidade Vila Esperança');
SET @un = LAST_INSERT_ID();

INSERT INTO usuarios(unidade_id, nome, email, papel)
VALUES (@un, 'Coordenação Central', 'coordenacao@redeesperanca.org', 'coordenador');
SET @usr = LAST_INSERT_ID();

INSERT INTO familias(unidade_id, nome_responsavel, cpf, endereco, bairro, num_pessoas, status, observacoes) VALUES
  (@un, 'Maria Aparecida dos Santos', '12345678909', 'Rua das Flores, 120',       'Vila Nova',         4, 'aguardando_cesta', 'Desempregada pós-pandemia, 2 crianças.'),
  (@un, 'João Carlos Pereira',        '98765432188', 'Av. Brasil, 450',           'Centro',            3, 'cesta_entregue',   'Pai solo, autônomo afetado.'),
  (@un, 'Ana Beatriz Souza',          '45612378912', 'Travessa Esperança, 15',    'Morumbi',           5, 'em_analise',       'Cadastro recente em verificação.'),
  (@un, 'Carlos Eduardo Lima',        '78932165444', 'Rua do Sol, 88',            'Jardim Paulistano', 2, 'aguardando_cesta', 'Idoso com problemas de saúde.');

INSERT INTO origens_doacao(nome) VALUES
  ('Doação Coletiva Municipal'), ('Supermercado Bom Preço'), ('Campanha Solidária Bairro'),
  ('Doação Anônima'), ('Associação Comercial'), ('Mutirão Igreja Local');

INSERT INTO itens(nome) VALUES
  ('Cesta Básica Completa'), ('Arroz (5kg)'), ('Feijão (1kg)'),
  ('Óleo de Soja (900ml)'), ('Leite em Pó (400g)'), ('Macarrão (500g)');

INSERT INTO lotes_estoque(unidade_id, item_id, origem_id, validade) VALUES
  (@un, (SELECT id FROM itens WHERE nome = 'Cesta Básica Completa'), (SELECT id FROM origens_doacao WHERE nome = 'Doação Coletiva Municipal'), '2026-11-30'),
  (@un, (SELECT id FROM itens WHERE nome = 'Arroz (5kg)'),           (SELECT id FROM origens_doacao WHERE nome = 'Supermercado Bom Preço'),    '2027-05-15'),
  (@un, (SELECT id FROM itens WHERE nome = 'Feijão (1kg)'),          (SELECT id FROM origens_doacao WHERE nome = 'Campanha Solidária Bairro'), '2026-12-10'),
  (@un, (SELECT id FROM itens WHERE nome = 'Óleo de Soja (900ml)'),  (SELECT id FROM origens_doacao WHERE nome = 'Doação Anônima'),           '2027-02-20'),
  (@un, (SELECT id FROM itens WHERE nome = 'Leite em Pó (400g)'),    (SELECT id FROM origens_doacao WHERE nome = 'Associação Comercial'),      '2026-10-15'),
  (@un, (SELECT id FROM itens WHERE nome = 'Macarrão (500g)'),       (SELECT id FROM origens_doacao WHERE nome = 'Mutirão Igreja Local'),      '2027-01-10');


SET @l1 = (SELECT l.id FROM lotes_estoque l JOIN itens i ON i.id = l.item_id WHERE i.nome = 'Cesta Básica Completa');
SET @l2 = (SELECT l.id FROM lotes_estoque l JOIN itens i ON i.id = l.item_id WHERE i.nome = 'Arroz (5kg)');
SET @l3 = (SELECT l.id FROM lotes_estoque l JOIN itens i ON i.id = l.item_id WHERE i.nome = 'Feijão (1kg)');
SET @l4 = (SELECT l.id FROM lotes_estoque l JOIN itens i ON i.id = l.item_id WHERE i.nome = 'Óleo de Soja (900ml)');
SET @l5 = (SELECT l.id FROM lotes_estoque l JOIN itens i ON i.id = l.item_id WHERE i.nome = 'Leite em Pó (400g)');
SET @l6 = (SELECT l.id FROM lotes_estoque l JOIN itens i ON i.id = l.item_id WHERE i.nome = 'Macarrão (500g)');

INSERT INTO movimentacoes_estoque(lote_id, tipo, delta, motivo, usuario_id) VALUES
  (@l1, 'entrada',  64, 'Carga inicial', @usr),
  (@l2, 'entrada', 120, 'Carga inicial', @usr),
  (@l3, 'entrada',  95, 'Carga inicial', @usr),
  (@l4, 'entrada',  50, 'Carga inicial', @usr),
  (@l5, 'entrada',  38, 'Carga inicial', @usr),
  (@l6, 'entrada',  80, 'Carga inicial', @usr);

INSERT INTO cestas(unidade_id, montada_por) VALUES (@un, @usr), (@un, @usr), (@un, @usr), (@un, @usr), (@un, @usr);


SET @fam1 = (SELECT id FROM familias WHERE nome_responsavel = 'Maria Aparecida dos Santos');
SET @fam2 = (SELECT id FROM familias WHERE nome_responsavel = 'Carlos Eduardo Lima');
SET @ces1 = (SELECT MIN(id) FROM cestas WHERE status = 'disponivel');
CALL agendar_entrega(@fam1, @ces1, '2026-10-09 14:00:00', 'retirada_centro', @usr, @ag1);
SET @ces2 = (SELECT MIN(id) FROM cestas WHERE status = 'disponivel');
CALL agendar_entrega(@fam2, @ces2, '2026-10-10 10:30:00', 'entrega_domiciliar', @usr, @ag2);

INSERT INTO campanhas(unidade_id, titulo, descricao, proxima_entrega) VALUES
  (@un, 'Mutirão de distribuição de cestas básicas',
   'Voltado para famílias monoparentais afetadas pelo desemprego pós-pandemia.', '2026-11-13');

INSERT INTO metas_mensais(unidade_id, mes, meta_entregas) VALUES (@un, '2026-11-01', 100);


SELECT VERSION() AS versao_mysql;               
SELECT * FROM v_dashboard_kpis;                 
SELECT * FROM v_status_familias;                
SELECT * FROM v_estoque_cards;                  
SELECT * FROM v_agendamentos;                   

