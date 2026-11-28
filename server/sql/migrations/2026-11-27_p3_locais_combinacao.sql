-- P3 — vínculo do local do evento com o catálogo.
-- Permite abrir as informações completas do lugar a partir do evento.
-- Idempotente.

DECLARE
  v_existe NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_existe FROM user_tab_columns
   WHERE table_name = 'LOCAL' AND column_name = 'CATALOGO_ID';
  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE local ADD (catalogo_id NUMBER)';
  END IF;

  SELECT COUNT(*) INTO v_existe FROM user_constraints
   WHERE constraint_name = 'FK_LOCAL_CATALOGO';
  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE q'[
      ALTER TABLE local ADD CONSTRAINT fk_local_catalogo
        FOREIGN KEY (catalogo_id)
        REFERENCES catalogo_lugar (id) ON DELETE SET NULL
    ]';
  END IF;

  SELECT COUNT(*) INTO v_existe FROM user_indexes
   WHERE index_name = 'IX_LOCAL_CATALOGO';
  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE
      'CREATE INDEX ix_local_catalogo ON local (catalogo_id)';
  END IF;
END;
/
