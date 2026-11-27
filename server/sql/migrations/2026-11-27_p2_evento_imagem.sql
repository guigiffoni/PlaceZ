-- P2 — imagem do evento.
-- Idempotente.

DECLARE
  v_existe NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_existe FROM user_tab_columns
   WHERE table_name = 'EVENTO' AND column_name = 'IMAGEM';
  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE evento ADD (imagem BLOB)';
  END IF;

  SELECT COUNT(*) INTO v_existe FROM user_tab_columns
   WHERE table_name = 'EVENTO' AND column_name = 'IMAGEM_MIME';
  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE evento ADD (imagem_mime VARCHAR2(40))';
  END IF;

  SELECT COUNT(*) INTO v_existe FROM user_tab_columns
   WHERE table_name = 'EVENTO' AND column_name = 'IMAGEM_ATUALIZADA_EM';
  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE evento ADD (imagem_atualizada_em TIMESTAMP)';
  END IF;
END;
/
