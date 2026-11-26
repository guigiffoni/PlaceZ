-- Fase 5 — combinação de dias.
-- Guarda o fuso do criador para converter a data/hora local da opção
-- escolhida em um timestamp UTC ao confirmar o evento.
-- Idempotente: pode ser executado novamente sem erro.

DECLARE
  v_existe NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_existe
    FROM user_tab_columns
   WHERE table_name = 'ENQUETE_DISPONIBILIDADE'
     AND column_name = 'FUSO_OFFSET_MINUTOS';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE
      'ALTER TABLE enquete_disponibilidade ADD (fuso_offset_minutos NUMBER(4) DEFAULT 0 NOT NULL)';
  END IF;
END;
/
