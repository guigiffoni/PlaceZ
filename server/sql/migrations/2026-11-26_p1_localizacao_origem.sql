-- P1 — origem da localização aproximada.
-- Valores: MAPA, GPS, BUSCA, COORDENADAS; REGIAO é usado apenas no fallback
-- legado de perfis antigos.
-- Idempotente.

DECLARE
  v_existe NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_existe
    FROM user_tab_columns
   WHERE table_name = 'USUARIO'
     AND column_name = 'LOCALIZACAO_ORIGEM';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE
      'ALTER TABLE usuario ADD (localizacao_origem VARCHAR2(20))';
  END IF;
END;
/
