-- P1 — foto de perfil em BLOB.
-- Idempotente: adiciona as colunas de foto apenas se ainda não existirem.

DECLARE
  v_existe NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_existe
    FROM user_tab_columns
   WHERE table_name = 'USUARIO' AND column_name = 'FOTO';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE usuario ADD (foto BLOB)';
  END IF;

  SELECT COUNT(*)
    INTO v_existe
    FROM user_tab_columns
   WHERE table_name = 'USUARIO' AND column_name = 'FOTO_MIME';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE usuario ADD (foto_mime VARCHAR2(40))';
  END IF;

  SELECT COUNT(*)
    INTO v_existe
    FROM user_tab_columns
   WHERE table_name = 'USUARIO' AND column_name = 'FOTO_ATUALIZADA_EM';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE
      'ALTER TABLE usuario ADD (foto_atualizada_em TIMESTAMP)';
  END IF;
END;
/
