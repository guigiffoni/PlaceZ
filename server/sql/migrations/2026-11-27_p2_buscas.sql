-- P2 — favoritos de amigos, permissão de convite em grupos e conversas
-- ocultas por usuário.
-- Idempotente.

DECLARE
  v_existe NUMBER;
BEGIN
  -- Favoritos (por usuário).
  SELECT COUNT(*)
    INTO v_existe
    FROM user_tables
   WHERE table_name = 'AMIZADE_FAVORITO';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE q'[
      CREATE TABLE amizade_favorito (
        usuario_id        NUMBER NOT NULL,
        amigo_usuario_id  NUMBER NOT NULL,
        criado_em         TIMESTAMP DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
        PRIMARY KEY (usuario_id, amigo_usuario_id),
        CONSTRAINT fk_favorito_usuario FOREIGN KEY (usuario_id)
          REFERENCES usuario (id) ON DELETE CASCADE,
        CONSTRAINT fk_favorito_amigo FOREIGN KEY (amigo_usuario_id)
          REFERENCES usuario (id) ON DELETE CASCADE,
        CONSTRAINT ck_favorito_par CHECK (usuario_id <> amigo_usuario_id)
      )
    ]';
    EXECUTE IMMEDIATE
      'CREATE INDEX ix_favorito_amigo ON amizade_favorito (amigo_usuario_id)';
  END IF;

  -- Grupo: membros podem adicionar pessoas.
  SELECT COUNT(*)
    INTO v_existe
    FROM user_tab_columns
   WHERE table_name = 'GRUPO'
     AND column_name = 'MEMBROS_PODEM_ADICIONAR';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE q'[
      ALTER TABLE grupo ADD (
        membros_podem_adicionar CHAR(1) DEFAULT 'N' NOT NULL
      )
    ]';
    EXECUTE IMMEDIATE q'[
      ALTER TABLE grupo ADD CONSTRAINT ck_grupo_adicionar
        CHECK (membros_podem_adicionar IN ('S', 'N'))
    ]';
  END IF;

  -- Conversas ocultas por usuário.
  SELECT COUNT(*)
    INTO v_existe
    FROM user_tables
   WHERE table_name = 'CONVERSA_OCULTA';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE q'[
      CREATE TABLE conversa_oculta (
        conversa_id              NUMBER NOT NULL,
        usuario_id               NUMBER NOT NULL,
        ocultada_ate_mensagem_id NUMBER DEFAULT 0 NOT NULL,
        criado_em                TIMESTAMP DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
        PRIMARY KEY (conversa_id, usuario_id),
        CONSTRAINT fk_oculta_conversa FOREIGN KEY (conversa_id)
          REFERENCES conversa (id) ON DELETE CASCADE,
        CONSTRAINT fk_oculta_usuario FOREIGN KEY (usuario_id)
          REFERENCES usuario (id) ON DELETE CASCADE,
        CONSTRAINT ck_oculta_mensagem CHECK (ocultada_ate_mensagem_id >= 0)
      )
    ]';
    EXECUTE IMMEDIATE
      'CREATE INDEX ix_oculta_usuario ON conversa_oculta (usuario_id)';
  END IF;
END;
/
