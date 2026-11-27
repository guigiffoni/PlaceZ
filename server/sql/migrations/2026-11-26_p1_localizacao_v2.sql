-- P1 — localização aproximada por bairro.
-- Guarda apenas o bairro/cidade e uma coordenada arredondada; a localização
-- exata escolhida no mapa/GPS/busca não é persistida.
-- Idempotente.

DECLARE
  v_existe NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_existe
    FROM user_tab_columns
   WHERE table_name = 'USUARIO' AND column_name = 'LOCALIZACAO_BAIRRO';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE
      'ALTER TABLE usuario ADD (localizacao_bairro VARCHAR2(120))';
  END IF;

  SELECT COUNT(*)
    INTO v_existe
    FROM user_tab_columns
   WHERE table_name = 'USUARIO' AND column_name = 'LOCALIZACAO_CIDADE';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE
      'ALTER TABLE usuario ADD (localizacao_cidade VARCHAR2(120))';
  END IF;

  SELECT COUNT(*)
    INTO v_existe
    FROM user_tab_columns
   WHERE table_name = 'USUARIO' AND column_name = 'LOCALIZACAO_LATITUDE';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE
      'ALTER TABLE usuario ADD (localizacao_latitude NUMBER(9, 6))';
  END IF;

  SELECT COUNT(*)
    INTO v_existe
    FROM user_tab_columns
   WHERE table_name = 'USUARIO' AND column_name = 'LOCALIZACAO_LONGITUDE';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE
      'ALTER TABLE usuario ADD (localizacao_longitude NUMBER(9, 6))';
  END IF;

  SELECT COUNT(*)
    INTO v_existe
    FROM user_tab_columns
   WHERE table_name = 'USUARIO'
     AND column_name = 'LOCALIZACAO_ATUALIZADA_EM';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE
      'ALTER TABLE usuario ADD (localizacao_atualizada_em TIMESTAMP)';
  END IF;
END;
/
