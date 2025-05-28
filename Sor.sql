--Triggers tabla sinc
GRANT INSERT ON C##DW.WATERMARK TO C##PRODUCCION;

-- =========================================
-- Trigger para tabla BD2_NO_HECHOS
-- =========================================
CREATE OR REPLACE TRIGGER C##PRODUCCION.TRG_SINC_BD2_NO_HECHOS
AFTER INSERT OR UPDATE ON C##PRODUCCION.BD2_NO_HECHOS
FOR EACH ROW
DECLARE
  v_operacion VARCHAR2(1);
BEGIN
  IF INSERTING THEN
    v_operacion := 'I';
  ELSIF UPDATING THEN
    v_operacion := 'U';
  END IF;

  INSERT INTO C##DW.WATERMARK (
    TABLA, PK, OPERACION, FECHA_INSERT
  ) VALUES (
    'BD2_NO_HECHOS',
    :NEW.FECHA_KEY,
    v_operacion,
    SYSDATE
  );
END;
/
-- =========================================
-- Trigger para tabla BD2_CORRELATIVOS
-- =========================================
CREATE OR REPLACE TRIGGER C##PRODUCCION.TRG_SINC_BD2_CORRELATIVOS
AFTER INSERT OR UPDATE ON C##PRODUCCION.BD2_CORRELATIVOS
FOR EACH ROW
DECLARE
  v_operacion VARCHAR2(1);
BEGIN
  IF INSERTING THEN
    v_operacion := 'I';
  ELSIF UPDATING THEN
    v_operacion := 'U';
  END IF;

  INSERT INTO C##DW.WATERMARK (
    TABLA, PK, OPERACION, FECHA_INSERT
  ) VALUES (
    'BD2_CORRELATIVOS',
    :NEW.VALOR,
    v_operacion,
    SYSDATE
  );
END;
/
-- =========================================
-- Trigger para tabla BD2_VALORES_DEFAULT
-- =========================================
CREATE OR REPLACE TRIGGER C##PRODUCCION.TRG_SINC_BD2_VALORES_DEFAULT
AFTER INSERT OR UPDATE ON C##PRODUCCION.BD2_VALORES_DEFAULT
FOR EACH ROW
DECLARE
  v_operacion VARCHAR2(1);
BEGIN
  IF INSERTING THEN
    v_operacion := 'I';
  ELSIF UPDATING THEN
    v_operacion := 'U';
  END IF;

  INSERT INTO C##DW.WATERMARK (
    TABLA, PK, OPERACION, FECHA_INSERT
  ) VALUES (
    'BD2_VALORES_DEFAULT',
    TRUNC(:NEW.VALOR),
    v_operacion,
    SYSDATE
  );
END;
/
-- =========================================
-- Trigger para tabla BD2_SEGUIMIENTO
-- =========================================
CREATE OR REPLACE TRIGGER C##PRODUCCION.TRG_SINC_BD2_VALORES_DEFAULT
AFTER INSERT OR UPDATE ON C##PRODUCCION.BD2_VALORES_DEFAULT
FOR EACH ROW
DECLARE
  v_operacion VARCHAR2(1);
BEGIN
  IF INSERTING THEN
    v_operacion := 'I';
  ELSIF UPDATING THEN
    v_operacion := 'U';
  END IF;

  INSERT INTO C##DW.WATERMARK (
    TABLA, PK, OPERACION, FECHA_INSERT
  ) VALUES (
    'BD2_VALORES_DEFAULT',
    TRUNC(:NEW.VALOR),
    v_operacion,
    SYSDATE
  );
END;
/

--C_DEVUELVE_CORRELATIVOS


