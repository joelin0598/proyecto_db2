/* =========================================================
   1.  CREACIÓN / AJUSTE DE ESQUEMAS Y CUOTAS
   =========================================================*/
-- Usuarios
CREATE USER C##stage      IDENTIFIED BY stage123      DEFAULT TABLESPACE USERS;
CREATE USER C##dw         IDENTIFIED BY dw123         DEFAULT TABLESPACE USERS;
CREATE USER C##produccion IDENTIFIED BY prod123       DEFAULT TABLESPACE USERS;

-- Cuotas
ALTER USER C##stage      QUOTA UNLIMITED ON USERS;
ALTER USER C##dw         QUOTA UNLIMITED ON USERS;
ALTER USER C##produccion QUOTA UNLIMITED ON USERS;

-- Roles básicos
GRANT CONNECT, RESOURCE TO C##stage, C##dw, C##produccion;

/* =========================================================
   2.  ESTRUCTURA DE TABLAS – STAGE
   =========================================================*/
CREATE TABLE C##stage.BD2_STG_DATOS (
  ANIO            NUMBER,
  FECHA           DATE,
  HORA            VARCHAR2(6),      -- ampliado para evitar ORA-12899
  RONDA           VARCHAR2(50),
  ESTADIO         VARCHAR2(100),
  CIUDAD          VARCHAR2(100),
  PAIS            VARCHAR2(100),
  EQUIPO_LOCAL    VARCHAR2(100),
  GOL_LOCAL       NUMBER,
  EQUIPO_VISITA   VARCHAR2(100),
  GOL_VISITA      NUMBER,
  ASISTENCIA      NUMBER
);

/* =========================================================
   3.  ESTRUCTURA DE TABLAS – DW
   =========================================================*/
-- DIMENSIONES
CREATE TABLE C##dw.BD2_DIM_HORA (
  HORA_KEY        NUMBER  PRIMARY KEY,
  HORA            VARCHAR2(6)
);

CREATE TABLE C##dw.BD2_DIM_SELECCION (
  SELECCION_KEY   NUMBER  PRIMARY KEY,
  NOMBRE_SELECCION VARCHAR2(100)
);

CREATE TABLE C##dw.BD2_DIM_RONDA (
  RONDA_KEY       NUMBER  PRIMARY KEY,
  NOMBRE_RONDA    VARCHAR2(50)
);

CREATE TABLE C##dw.BD2_DIM_PAIS_ORGANIZADOR (
  PAIS_KEY        NUMBER  PRIMARY KEY,
  NOMBRE_PAIS_ORGANIZADOR VARCHAR2(100)
);

CREATE TABLE C##dw.BD2_DIM_CIUDAD (
  CIUDAD_KEY      NUMBER  PRIMARY KEY,
  CIUDAD_ORGANIZADOR VARCHAR2(100),
  PAIS_KEY        NUMBER REFERENCES C##dw.BD2_DIM_PAIS_ORGANIZADOR
);

CREATE TABLE C##dw.BD2_DIM_ESTADIO (
  ESTADIO_KEY     NUMBER  PRIMARY KEY,
  NOMBRE_ESTADIO  VARCHAR2(100),
  CIUDAD_KEY      NUMBER REFERENCES C##dw.BD2_DIM_CIUDAD
);

-- HECHOS
CREATE TABLE C##dw.BD2_HECHOS (
  ANIO            NUMBER,
  FECHA_KEY       NUMBER,
  HORA_KEY        NUMBER,
  RONDA_KEY       NUMBER,
  ESTADIO_KEY     NUMBER,
  LOCAL_KEY       NUMBER,
  VISITANTE_KEY   NUMBER,
  GOL_LOCAL       NUMBER,
  GOL_VISITA      NUMBER,
  ASISTENCIA      NUMBER
);

-- WATERMARK (DW)
CREATE TABLE C##dw.WATERMARK (
  TABLA           VARCHAR2(30),
  PK              NUMBER(10),
  OPERACION       VARCHAR2(1),
  FECHA_INSERT    DATE,
  MIGRO           CHAR(1) DEFAULT 'N',
  FECHA_OPERADO   DATE
);

/* =========================================================
   4.  ESTRUCTURA DE TABLAS – PRODUCCIÓN
   =========================================================*/
CREATE TABLE C##produccion.BD2_NO_HECHOS (
  ANIO            NUMBER,
  FECHA_KEY       NUMBER,
  FECHA_COD       DATE,
  HORA_KEY        NUMBER,
  HORA_COD        VARCHAR2(6),
  RONDA_KEY       NUMBER,
  NOMBRE_RONDA    VARCHAR2(50),
  ESTADIO_KEY     NUMBER,
  ESTADIO         VARCHAR2(100),
  CIUDAD          VARCHAR2(100),
  PAIS            VARCHAR2(100),
  LOCAL_KEY       NUMBER,
  EQUIPO_LOCAL    VARCHAR2(100),
  VISITANTE_KEY   NUMBER,
  EQUIPO_VISITA   VARCHAR2(100),
  GOL_LOCAL       NUMBER,
  GOL_VISITA      NUMBER,
  ASISTENCIA      NUMBER
);

CREATE TABLE C##produccion.BD2_CORRELATIVOS (
  DIMENSION       VARCHAR2(30) PRIMARY KEY,
  VALOR           NUMBER(10)
);

CREATE TABLE C##produccion.BD2_VALORES_DEFAULT (
  CAMPO           VARCHAR2(30),
  VALOR           NUMBER(38,2)
);

CREATE TABLE C##produccion.BD2_SEGUIMIENTO (
  DIMENSION       VARCHAR2(30),
  USUARIO         VARCHAR2(30),
  FECHA           DATE
);

/* =========================================================
   5.  PERMISOS ENTRE AMBIENTES
   =========================================================*/
-- Stage necesita leer/actualizar Producción
GRANT SELECT, UPDATE ON C##produccion.BD2_NO_HECHOS       TO C##stage;
GRANT SELECT, UPDATE ON C##produccion.BD2_CORRELATIVOS     TO C##stage;
GRANT SELECT, UPDATE ON C##produccion.BD2_VALORES_DEFAULT  TO C##stage;
GRANT SELECT, UPDATE ON C##produccion.BD2_SEGUIMIENTO      TO C##stage;

-- DW solo lectura sobre Stage
GRANT SELECT ON C##stage.BD2_STG_DATOS TO C##dw;

-- Producción lectura sobre DW (dimensiones / hechos)
GRANT SELECT ON C##dw.BD2_DIM_HORA             TO C##produccion;
GRANT SELECT ON C##dw.BD2_DIM_SELECCION        TO C##produccion;
GRANT SELECT ON C##dw.BD2_DIM_RONDA            TO C##produccion;
GRANT SELECT ON C##dw.BD2_DIM_PAIS_ORGANIZADOR TO C##produccion;
GRANT SELECT ON C##dw.BD2_DIM_CIUDAD           TO C##produccion;
GRANT SELECT ON C##dw.BD2_DIM_ESTADIO          TO C##produccion;
GRANT SELECT ON C##dw.BD2_HECHOS               TO C##produccion;


-- Permitir seleccionar datos desde la tabla de hechos
GRANT SELECT ON C##produccion.BD2_NO_HECHOS TO C##stage;

-- Permitir insertar en la tabla de seguimiento
GRANT INSERT ON C##produccion.BD2_SEGUIMIENTO TO C##stage;

-- Dar acceso a BD2_CORRELATIVOS
GRANT SELECT, INSERT, UPDATE ON C##PRODUCCION.BD2_CORRELATIVOS TO C##dw;

/* =========================================================
   6.  SINÓNIMOS (opcional pero práctico)
   =========================================================*/
CREATE OR REPLACE SYNONYM WATERMARK FOR C##dw.WATERMARK;
CREATE OR REPLACE SYNONYM STG_DATOS FOR C##stage.BD2_STG_DATOS;

/* =========================================================
   7.  TRIGGER DE AUDITORÍA EN PRODUCCIÓN → WATERMARK
   (insert / update en tablas transaccionales)
   =========================================================*/
CREATE OR REPLACE TRIGGER C##produccion.TRG_SINC_BD2_NO_HECHOS
AFTER INSERT OR UPDATE ON C##produccion.BD2_NO_HECHOS
FOR EACH ROW
BEGIN
  INSERT INTO C##dw.WATERMARK (TABLA, PK, OPERACION, FECHA_INSERT)
  VALUES ('BD2_NO_HECHOS',
          NVL(:NEW.FECHA_KEY, -1),
          CASE WHEN INSERTING THEN 'I' ELSE 'U' END,
          SYSDATE);
END;
/

-- Clona el trigger para las demás tablas de Producción que quieras auditar
/* … (disponible en tu script original, ajustado a WATERMARK DW) … */

/* =========================================================
   8.  PROCEDIMIENTO  PRC_SINCRONIZACION  (Stage)
   =========================================================*/

CREATE OR REPLACE PROCEDURE C##stage.PRC_SINCRONIZACION AS
BEGIN
  -- Sincroniza tabla de Stage con Producción
  DELETE FROM BD2_STG_DATOS
  WHERE 1 = 1;

  INSERT INTO BD2_STG_DATOS
    SELECT ANIO,
           FECHA_COD,
           HORA_COD,
           NOMBRE_RONDA,
           ESTADIO,
           CIUDAD,
           PAIS,
           EQUIPO_LOCAL,
           GOL_LOCAL,
           EQUIPO_VISITA,
           GOL_VISITA,
           ASISTENCIA
      FROM C##produccion.BD2_NO_HECHOS;

  INSERT INTO C##produccion.BD2_SEGUIMIENTO
    (DIMENSION, USUARIO, FECHA)
  VALUES
    ('BD2_STG_DATOS', USER, SYSDATE);
END;
/

/* =========================================================
   9.  PROCEDIMIENTO  PRC_DEVUELVE_CORRELATIVOS  (DW)
   =========================================================*/
CREATE OR REPLACE PROCEDURE C##dw.PRC_DEVUELVE_CORRELATIVOS
  (p_dimension IN  VARCHAR2,
   p_valor     OUT NUMBER) IS
BEGIN
  SELECT valor
    INTO p_valor
    FROM C##PRODUCCION.BD2_CORRELATIVOS
   WHERE dimension = p_dimension
   FOR UPDATE;

  UPDATE C##PRODUCCION.BD2_CORRELATIVOS
     SET valor = valor + 1
   WHERE dimension = p_dimension;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    p_valor := 1;
    INSERT INTO C##PRODUCCION.BD2_CORRELATIVOS (dimension, valor)
    VALUES (p_dimension, 2);
END;
/

/* =========================================================
  10. TRIGGERS DE CLAVE SURROGADA EN CADA DIMENSIÓN (DW)
   =========================================================*/
-- Ejemplo: HORA
CREATE OR REPLACE TRIGGER C##dw.TRG_PK_DIM_HORA
BEFORE INSERT ON C##dw.BD2_DIM_HORA
FOR EACH ROW
BEGIN
  C##dw.PRC_DEVUELVE_CORRELATIVOS('BD2_DIM_HORA', :NEW.HORA_KEY);
END;
/

-- Replica para cada dimensión
CREATE OR REPLACE TRIGGER C##dw.TRG_PK_DIM_SELECCION
BEFORE INSERT ON C##dw.BD2_DIM_SELECCION
FOR EACH ROW
BEGIN
  C##dw.PRC_DEVUELVE_CORRELATIVOS('BD2_DIM_SELECCION', :NEW.SELECCION_KEY);
END;
/

CREATE OR REPLACE TRIGGER C##dw.TRG_PK_DIM_RONDA
BEFORE INSERT ON C##dw.BD2_DIM_RONDA
FOR EACH ROW
BEGIN
  C##dw.PRC_DEVUELVE_CORRELATIVOS('BD2_DIM_RONDA', :NEW.RONDA_KEY);
END;
/

CREATE OR REPLACE TRIGGER C##dw.TRG_PK_DIM_PAIS
BEFORE INSERT ON C##dw.BD2_DIM_PAIS_ORGANIZADOR
FOR EACH ROW
BEGIN
  C##dw.PRC_DEVUELVE_CORRELATIVOS('BD2_DIM_PAIS_ORGANIZADOR', :NEW.PAIS_KEY);
END;
/

CREATE OR REPLACE TRIGGER C##dw.TRG_PK_DIM_CIUDAD
BEFORE INSERT ON C##dw.BD2_DIM_CIUDAD
FOR EACH ROW
BEGIN
  C##dw.PRC_DEVUELVE_CORRELATIVOS('BD2_DIM_CIUDAD', :NEW.CIUDAD_KEY);
END;
/

CREATE OR REPLACE TRIGGER C##dw.TRG_PK_DIM_ESTADIO
BEFORE INSERT ON C##dw.BD2_DIM_ESTADIO
FOR EACH ROW
BEGIN
  C##dw.PRC_DEVUELVE_CORRELATIVOS('BD2_DIM_ESTADIO', :NEW.ESTADIO_KEY);
END;
/

/* =========================================================
  11. PROCEDIMIENTOS DE CARGA / MERGE POR DIMENSIÓN
   =========================================================*/
-- Hora
CREATE OR REPLACE PROCEDURE C##dw.PRC_DIM_HORA(p_accion IN NUMBER) AS
BEGIN
  IF p_accion = 1 THEN
    MERGE INTO BD2_DIM_HORA d
    USING (SELECT DISTINCT HORA FROM C##stage.BD2_STG_DATOS) s
    ON (d.HORA = s.HORA)
    WHEN NOT MATCHED THEN
      INSERT (HORA_KEY, HORA) VALUES (NULL, s.HORA);
  END IF;
END;
/

-- Selección
CREATE OR REPLACE PROCEDURE C##dw.PRC_DIM_SELECCION(p_accion IN NUMBER) AS
BEGIN
  IF p_accion = 1 THEN
    MERGE INTO BD2_DIM_SELECCION d
    USING (
      SELECT DISTINCT EQUIPO_LOCAL AS NOMBRE_SELECCION FROM C##stage.BD2_STG_DATOS
      UNION
      SELECT DISTINCT EQUIPO_VISITA FROM C##stage.BD2_STG_DATOS
    ) s
    ON (d.NOMBRE_SELECCION = s.NOMBRE_SELECCION)
    WHEN NOT MATCHED THEN
      INSERT (SELECCION_KEY, NOMBRE_SELECCION)
      VALUES (NULL, s.NOMBRE_SELECCION);
  END IF;
END;
/

-- Ronda
CREATE OR REPLACE PROCEDURE C##dw.PRC_DIM_RONDA(p_accion IN NUMBER) AS
BEGIN
  IF p_accion = 1 THEN
    MERGE INTO BD2_DIM_RONDA d
    USING (SELECT DISTINCT RONDA AS NOMBRE_RONDA FROM C##stage.BD2_STG_DATOS) s
    ON (d.NOMBRE_RONDA = s.NOMBRE_RONDA)
    WHEN NOT MATCHED THEN
      INSERT (RONDA_KEY, NOMBRE_RONDA) VALUES (NULL, s.NOMBRE_RONDA);
  END IF;
END;
/

-- País
CREATE OR REPLACE PROCEDURE C##dw.PRC_DIM_PAIS(p_accion IN NUMBER) AS
BEGIN
  IF p_accion = 1 THEN
    MERGE INTO BD2_DIM_PAIS_ORGANIZADOR d
    USING (SELECT DISTINCT PAIS AS NOMBRE_PAIS_ORGANIZADOR FROM C##stage.BD2_STG_DATOS) s
    ON (d.NOMBRE_PAIS_ORGANIZADOR = s.NOMBRE_PAIS_ORGANIZADOR)
    WHEN NOT MATCHED THEN
      INSERT (PAIS_KEY, NOMBRE_PAIS_ORGANIZADOR) VALUES (NULL, s.NOMBRE_PAIS_ORGANIZADOR);
  END IF;
END;
/

-- Ciudad
CREATE OR REPLACE PROCEDURE C##dw.PRC_DIM_CIUDAD(p_accion IN NUMBER) AS
BEGIN
  IF p_accion = 1 THEN
    MERGE INTO BD2_DIM_CIUDAD d
    USING (
      SELECT DISTINCT
             CIUDAD           AS CIUDAD_ORGANIZADOR,
             (SELECT p.PAIS_KEY
                FROM BD2_DIM_PAIS_ORGANIZADOR p
               WHERE p.NOMBRE_PAIS_ORGANIZADOR = s.PAIS
               FETCH FIRST 1 ROWS ONLY) AS PAIS_KEY
      FROM   C##stage.BD2_STG_DATOS s
    ) s
    ON (d.CIUDAD_ORGANIZADOR = s.CIUDAD_ORGANIZADOR)
    WHEN NOT MATCHED THEN
      INSERT (CIUDAD_KEY, CIUDAD_ORGANIZADOR, PAIS_KEY)
      VALUES (NULL, s.CIUDAD_ORGANIZADOR, s.PAIS_KEY);
  END IF;
END;
/

-- Estadio
CREATE OR REPLACE PROCEDURE C##dw.PRC_DIM_ESTADIO(p_accion IN NUMBER) AS
BEGIN
  IF p_accion = 1 THEN
    MERGE INTO BD2_DIM_ESTADIO d
    USING (
      SELECT DISTINCT
             ESTADIO AS NOMBRE_ESTADIO,
             (SELECT c.CIUDAD_KEY
                FROM BD2_DIM_CIUDAD c
               WHERE c.CIUDAD_ORGANIZADOR = s.CIUDAD
               FETCH FIRST 1 ROWS ONLY) AS CIUDAD_KEY
        FROM C##stage.BD2_STG_DATOS s
    ) s
    ON (d.NOMBRE_ESTADIO = s.NOMBRE_ESTADIO)
    WHEN NOT MATCHED THEN
      INSERT (ESTADIO_KEY, NOMBRE_ESTADIO, CIUDAD_KEY)
      VALUES (NULL, s.NOMBRE_ESTADIO, s.CIUDAD_KEY);
  END IF;
END;
/

/* =========================================================
  12. PROCEDIMIENTO DE CONSTRUCCIÓN DE HECHOS (DW)
   =========================================================*/
CREATE OR REPLACE PROCEDURE C##dw.PRC_CONSTRUYE_HECHOS(p_accion IN NUMBER) AS
BEGIN
  IF p_accion = 1 THEN
    INSERT INTO BD2_HECHOS
    SELECT s.ANIO,
           TO_NUMBER(TO_CHAR(s.FECHA,'J'))                          AS FECHA_KEY,
           h.HORA_KEY,
           r.RONDA_KEY,
           e.ESTADIO_KEY,
           l.SELECCION_KEY,
           v.SELECCION_KEY,
           s.GOL_LOCAL,
           s.GOL_VISITA,
           s.ASISTENCIA
      FROM C##stage.BD2_STG_DATOS s
      LEFT JOIN BD2_DIM_HORA              h ON (h.HORA               = s.HORA)
      LEFT JOIN BD2_DIM_RONDA             r ON (r.NOMBRE_RONDA       = s.RONDA)
      LEFT JOIN BD2_DIM_ESTADIO           e ON (e.NOMBRE_ESTADIO      = s.ESTADIO)
      LEFT JOIN BD2_DIM_SELECCION         l ON (l.NOMBRE_SELECCION    = s.EQUIPO_LOCAL)
      LEFT JOIN BD2_DIM_SELECCION         v ON (v.NOMBRE_SELECCION    = s.EQUIPO_VISITA);
  END IF;
END;
/

-- Permisos para que Stage pueda ejecutar procesos de sincronización DW si se requiere
GRANT EXECUTE ON C##dw.PRC_CONSTRUYE_HECHOS   TO C##stage;
GRANT EXECUTE ON C##dw.PRC_DIM_HORA           TO C##stage;
GRANT EXECUTE ON C##dw.PRC_DIM_SELECCION      TO C##stage;
GRANT EXECUTE ON C##dw.PRC_DIM_RONDA          TO C##stage;
GRANT EXECUTE ON C##dw.PRC_DIM_PAIS           TO C##stage;
GRANT EXECUTE ON C##dw.PRC_DIM_CIUDAD         TO C##stage;
GRANT EXECUTE ON C##dw.PRC_DIM_ESTADIO        TO C##stage;
GRANT EXECUTE ON C##dw.PRC_DEVUELVE_CORRELATIVOS TO C##stage;

/* =========================================================
  13.  FIN DEL SCRIPT
   =========================================================*/

--PRUEBA DE FUNCIONAMIENTO
select * FROM C##produccion.BD2_CORRELATIVOS;

INSERT INTO C##PRODUCCION.BD2_CORRELATIVOS (DIMENSION, VALOR)
VALUES ('PRUEBA_DIM', 1);

COMMIT;

DECLARE
  v_valor NUMBER;
BEGIN
  -- Llama al procedimiento
  C##DW.PRC_DEVUELVE_CORRELATIVOS('PRUEBA_DIM', v_valor);

  -- Muestra el resultado
  DBMS_OUTPUT.PUT_LINE('Nuevo correlativo: ' || v_valor);
END;
/



CREATE OR REPLACE PROCEDURE C##dw.PRC_LLENA_HECHOS(p_accion IN NUMBER) AS

  -- Cursor para recorrer stage y LEFT JOIN con dimensiones
  CURSOR cur_stage IS
    SELECT
      s.ANIO,
      s.FECHA,
      s.HORA,
      s.RONDA,
      s.ESTADIO,
      s.CIUDAD,
      s.PAIS,
      s.EQUIPO_LOCAL,
      s.GOL_LOCAL,
      s.EQUIPO_VISITA,
      s.GOL_VISITA,
      s.ASISTENCIA,
      h.HORA_KEY,
      r.RONDA_KEY,
      e.ESTADIO_KEY,
      l.SELECCION_KEY AS LOCAL_KEY,
      v.SELECCION_KEY AS VISITANTE_KEY
    FROM C##stage.BD2_STG_DATOS s
      LEFT JOIN C##dw.BD2_DIM_HORA h ON h.HORA = s.HORA
      LEFT JOIN C##dw.BD2_DIM_RONDA r ON r.NOMBRE_RONDA = s.RONDA
      LEFT JOIN C##dw.BD2_DIM_ESTADIO e ON e.NOMBRE_ESTADIO = s.ESTADIO
      LEFT JOIN C##dw.BD2_DIM_SELECCION l ON l.NOMBRE_SELECCION = s.EQUIPO_LOCAL
      LEFT JOIN C##dw.BD2_DIM_SELECCION v ON v.NOMBRE_SELECCION = s.EQUIPO_VISITA;

BEGIN
  IF p_accion = 1 THEN
    FOR rec IN cur_stage LOOP
      
      -- Validar que todas las claves existan
      IF rec.HORA_KEY IS NOT NULL AND
         rec.RONDA_KEY IS NOT NULL AND
         rec.ESTADIO_KEY IS NOT NULL AND
         rec.LOCAL_KEY IS NOT NULL AND
         rec.VISITANTE_KEY IS NOT NULL THEN

        -- Insertar en hechos
        INSERT INTO C##dw.BD2_HECHOS (
          ANIO,
          FECHA_KEY,
          HORA_KEY,
          RONDA_KEY,
          ESTADIO_KEY,
          LOCAL_KEY,
          VISITANTE_KEY,
          GOL_LOCAL,
          GOL_VISITA,
          ASISTENCIA
        ) VALUES (
          rec.ANIO,
          TO_NUMBER(TO_CHAR(rec.FECHA,'J')),
          rec.HORA_KEY,
          rec.RONDA_KEY,
          rec.ESTADIO_KEY,
          rec.LOCAL_KEY,
          rec.VISITANTE_KEY,
          rec.GOL_LOCAL,
          rec.GOL_VISITA,
          rec.ASISTENCIA
        );

      ELSE
        -- Insertar en nohechos con los datos originales de stage (los campos según definición de BD2_NO_HECHOS)
        INSERT INTO C##produccion.BD2_NO_HECHOS (
          ANIO,
          FECHA_KEY,
          FECHA_COD,
          HORA_KEY,
          HORA_COD,
          RONDA_KEY,
          NOMBRE_RONDA,
          ESTADIO_KEY,
          ESTADIO,
          CIUDAD,
          PAIS,
          LOCAL_KEY,
          EQUIPO_LOCAL,
          VISITANTE_KEY,
          EQUIPO_VISITA,
          GOL_LOCAL,
          GOL_VISITA,
          ASISTENCIA
        ) VALUES (
          rec.ANIO,
          NULL,             -- FECHA_KEY no existe
          rec.FECHA,
          NULL,             -- HORA_KEY no existe
          rec.HORA,
          NULL,             -- RONDA_KEY no existe
          rec.RONDA,
          NULL,             -- ESTADIO_KEY no existe
          rec.ESTADIO,
          rec.CIUDAD,
          rec.PAIS,
          NULL,             -- LOCAL_KEY no existe
          rec.EQUIPO_LOCAL,
          NULL,             -- VISITANTE_KEY no existe
          rec.EQUIPO_VISITA,
          rec.GOL_LOCAL,
          rec.GOL_VISITA,
          rec.ASISTENCIA
        );
      END IF;

    END LOOP;

    COMMIT;

  END IF;
END;
/


CREATE OR REPLACE PROCEDURE C##produccion.PRC_LLENA_SEGUIMIENTO(p_dimension IN VARCHAR2) AS
BEGIN
  INSERT INTO C##produccion.BD2_SEGUIMIENTO (DIMENSION, USUARIO, FECHA)
  VALUES (p_dimension, USER, SYSDATE);

  COMMIT;
END;
/


CREATE OR REPLACE PROCEDURE C##dw.PRC_CONSTRUYE_HECHOS(p_accion IN NUMBER) AS
BEGIN
  IF p_accion = 1 THEN
    -- Llenado desde tabla STAGE, validando claves no nulas (como antes)
    INSERT INTO BD2_HECHOS (
      ANIO,
      FECHA_KEY,
      HORA_KEY,
      RONDA_KEY,
      ESTADIO_KEY,
      LOCAL_KEY,
      VISITANTE_KEY,
      GOL_LOCAL,
      GOL_VISITA,
      ASISTENCIA
    )
    SELECT
      s.ANIO,
      TO_NUMBER(TO_CHAR(s.FECHA, 'J')) AS FECHA_KEY,
      h.HORA_KEY,
      r.RONDA_KEY,
      e.ESTADIO_KEY,
      l.SELECCION_KEY,
      v.SELECCION_KEY,
      s.GOL_LOCAL,
      s.GOL_VISITA,
      s.ASISTENCIA
    FROM C##stage.BD2_STG_DATOS s
      LEFT JOIN BD2_DIM_HORA h ON h.HORA = s.HORA
      LEFT JOIN BD2_DIM_RONDA r ON r.NOMBRE_RONDA = s.RONDA
      LEFT JOIN BD2_DIM_ESTADIO e ON e.NOMBRE_ESTADIO = s.ESTADIO
      LEFT JOIN BD2_DIM_SELECCION l ON l.NOMBRE_SELECCION = s.EQUIPO_LOCAL
      LEFT JOIN BD2_DIM_SELECCION v ON v.NOMBRE_SELECCION = s.EQUIPO_VISITA
    WHERE
      h.HORA_KEY IS NOT NULL
      AND r.RONDA_KEY IS NOT NULL
      AND e.ESTADIO_KEY IS NOT NULL
      AND l.SELECCION_KEY IS NOT NULL
      AND v.SELECCION_KEY IS NOT NULL;

  ELSIF p_accion = 2 THEN
    -- Llenado desde tabla NO_HECHOS sin validar claves nulas
    -- Se asume que las dimensiones ya existen y las FK serán correctas o se permite nulos en BD2_HECHOS
    INSERT INTO BD2_HECHOS (
      ANIO,
      FECHA_KEY,
      HORA_KEY,
      RONDA_KEY,
      ESTADIO_KEY,
      LOCAL_KEY,
      VISITANTE_KEY,
      GOL_LOCAL,
      GOL_VISITA,
      ASISTENCIA
    )
    SELECT
      n.ANIO,
      n.FECHA_KEY,
      n.HORA_KEY,
      n.RONDA_KEY,
      n.ESTADIO_KEY,
      n.LOCAL_KEY,
      n.VISITANTE_KEY,
      n.GOL_LOCAL,
      n.GOL_VISITA,
      n.ASISTENCIA
    FROM C##produccion.BD2_NO_HECHOS n;
    
    -- Se asume que el procedimiento PRC_DIM_TIEMPO se ejecuta antes o fuera de este procedimiento
  END IF;

  COMMIT;
END;
/

CREATE OR REPLACE PROCEDURE C##dw.PRC_PROCESA_NOHECHOS AS

  CURSOR cur_nohechos IS
    SELECT 
      FECHA_KEY,
      HORA_KEY,
      RONDA_KEY,
      ESTADIO_KEY,
      LOCAL_KEY,
      VISITANTE_KEY
    FROM C##produccion.BD2_NO_HECHOS;

  -- Variables para control de llamadas (evitar llamadas múltiples si no hay NULLs)
  v_llamar_hora BOOLEAN := FALSE;
  v_llamar_ronda BOOLEAN := FALSE;
  v_llamar_estadio BOOLEAN := FALSE;
  v_llamar_local BOOLEAN := FALSE;
  v_llamar_visitante BOOLEAN := FALSE;
  v_llamar_fecha BOOLEAN := FALSE;

BEGIN

  -- Inicializamos flags
  v_llamar_hora := FALSE;
  v_llamar_ronda := FALSE;
  v_llamar_estadio := FALSE;
  v_llamar_local := FALSE;
  v_llamar_visitante := FALSE;
  v_llamar_fecha := FALSE;

  FOR rec IN cur_nohechos LOOP

    -- Detectar claves nulas
    IF rec.FECHA_KEY IS NULL THEN
      v_llamar_fecha := TRUE;
    END IF;

    IF rec.HORA_KEY IS NULL THEN
      v_llamar_hora := TRUE;
    END IF;

    IF rec.RONDA_KEY IS NULL THEN
      v_llamar_ronda := TRUE;
    END IF;

    IF rec.ESTADIO_KEY IS NULL THEN
      v_llamar_estadio := TRUE;
    END IF;

    IF rec.LOCAL_KEY IS NULL THEN
      v_llamar_local := TRUE;
    END IF;

    IF rec.VISITANTE_KEY IS NULL THEN
      v_llamar_visitante := TRUE;
    END IF;

    -- Si ya detectamos que se debe llamar a todos, salimos del cursor para optimizar
    IF v_llamar_fecha AND v_llamar_hora AND v_llamar_ronda AND v_llamar_estadio AND v_llamar_local AND v_llamar_visitante THEN
      EXIT;
    END IF;

  END LOOP;

  -- Llamadas a procedimientos correspondientes sólo si detectamos claves nulas

  IF v_llamar_fecha THEN
    -- Asumiendo que PRC_DIM_TIEMPO existe y recibe parámetro 2 para procesar no_hechos
    C##dw.PRC_DIM_TIEMPO(2);
  END IF;

  IF v_llamar_hora THEN
    C##dw.PRC_DIM_HORA(2);
  END IF;

  IF v_llamar_ronda THEN
    C##dw.PRC_DIM_RONDA(2);
  END IF;

  IF v_llamar_estadio THEN
    C##dw.PRC_DIM_ESTADIO(2);
  END IF;

  IF v_llamar_local THEN
    C##dw.PRC_DIM_SELECCION(2);  -- Asumo que local y visitante usan misma dimensión SELECCION
  END IF;

  IF v_llamar_visitante THEN
    C##dw.PRC_DIM_SELECCION(2);
  END IF;

  COMMIT;

END;

