-- P1 — contador de mensagens não lidas.
-- Idempotente: cria a tabela de leitura e o índice por usuário.

DECLARE
  v_existe NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_existe
    FROM user_tables
   WHERE table_name = 'CONVERSA_LEITURA';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE q'[
      CREATE TABLE conversa_leitura (
        conversa_id        NUMBER NOT NULL,
        usuario_id         NUMBER NOT NULL,
        ultima_mensagem_id NUMBER DEFAULT 0 NOT NULL,
        atualizado_em      TIMESTAMP DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
        PRIMARY KEY (conversa_id, usuario_id),
        CONSTRAINT fk_leitura_conversa FOREIGN KEY (conversa_id)
          REFERENCES conversa (id) ON DELETE CASCADE,
        CONSTRAINT fk_leitura_usuario FOREIGN KEY (usuario_id)
          REFERENCES usuario (id) ON DELETE CASCADE,
        CONSTRAINT ck_leitura_mensagem CHECK (ultima_mensagem_id >= 0)
      )
    ]';
  END IF;

  SELECT COUNT(*)
    INTO v_existe
    FROM user_indexes
   WHERE index_name = 'IX_LEITURA_USUARIO';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE
      'CREATE INDEX ix_leitura_usuario ON conversa_leitura (usuario_id)';
  END IF;
END;
/
