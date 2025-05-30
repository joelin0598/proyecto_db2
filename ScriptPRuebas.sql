
--**********************************************************
--********** Prueba 01: Creación de Usuarios y Roles **********
-- Se espera que se creen los usuarios sin errores.
-- Si falla por el TABLESPACE 'USERS', cambiar a uno válido.
--**********************************************************

-- Ejecutar el bloque de creación de usuarios y cuotas.
-- NOTA: Comenta si ya existen.
-- CREATE USER C##stage IDENTIFIED BY stage123;
-- CREATE USER C##dw IDENTIFIED BY dw123;
-- CREATE USER C##produccion IDENTIFIED BY prod123;
-- ALTER USER C##stage QUOTA UNLIMITED ON USERS;
-- GRANT CONNECT, RESOURCE TO C##stage, C##dw, C##produccion;

--**********************************************************
--********** Prueba 02: Verificación de Tablas por Usuario **********
-- Esperado: Mostrar las tablas propias creadas en cada esquema.
--**********************************************************
SELECT table_name FROM all_tables WHERE owner = 'C##STAGE';
SELECT table_name FROM all_tables WHERE owner = 'C##DW';
SELECT table_name FROM all_tables WHERE owner = 'C##PRODUCCION';

--**********************************************************
--********** Prueba 03: Verificación de Sinónimos **********
-- Se espera ver todos los sinónimos definidos correctamente.
--**********************************************************
SELECT synonym_name, table_owner, table_name FROM all_synonyms
WHERE synonym_name LIKE 'BD2_%';

--**********************************************************
--********** Prueba 04: Insertar en Producción y Activar Trigger **********
-- Inserta datos de prueba en BD2_NO_HECHOS y activa TRG_TABLA_SINC.
--**********************************************************
INSERT INTO C##PRODUCCION.BD2_NO_HECHOS (
  ANIO, FECHA_KEY, FECHA_COD, HORA_KEY, HORA_COD, RONDA_KEY,
  NOMBRE_RONDA, ESTADIO_KEY, ESTADIO, CIUDAD, PAIS,
  LOCAL_KEY, EQUIPO_LOCAL, VISITANTE_KEY, EQUIPO_VISITA,
  GOL_LOCAL, GOL_VISITA, ASISTENCIA
) VALUES (
  2022, NULL, TO_DATE('2022-11-20','YYYY-MM-DD'), NULL, '18:00', NULL,
  'Fase de Grupos', NULL, 'Estadio Lusail', 'Lusail', 'Qatar',
  NULL, 'Qatar', NULL, 'Ecuador',
  0, 2, 67349
);

--**********************************************************
--********** Prueba 05: Verificación de Trigger y Watermark **********
-- Se espera encontrar un nuevo registro en WATERMARK.
--**********************************************************
SELECT * FROM C##DW.WATERMARK WHERE TABLA = 'BD2_NO_HECHOS';

--**********************************************************
--********** Prueba 06: Ejecutar PRC_SINCRONIZACION **********
-- Se espera que STAGE quede con los datos cargados desde NO_HECHOS.
--**********************************************************
EXEC C##STAGE.PRC_SINCRONIZACION;
SELECT * FROM C##STAGE.BD2_STG_DATOS;

--**********************************************************
--********** Prueba 07: Llenado de Dimensiones con parámetro 1 **********
-- Ejecutar cada PRC_DIM_XXX(1) y verificar inserciones con SELECT.
--**********************************************************
EXEC C##DW.PRC_DIM_HORA(1);
EXEC C##DW.PRC_DIM_SELECCION(1);
EXEC C##DW.PRC_DIM_RONDA(1);
EXEC C##DW.PRC_DIM_PAIS(1);
EXEC C##DW.PRC_DIM_CIUDAD(1);
EXEC C##DW.PRC_DIM_ESTADIO(1);

SELECT * FROM C##DW.BD2_DIM_HORA;
SELECT * FROM C##DW.BD2_DIM_SELECCION;
SELECT * FROM C##DW.BD2_DIM_RONDA;
SELECT * FROM C##DW.BD2_DIM_PAIS_ORGANIZADOR;
SELECT * FROM C##DW.BD2_DIM_CIUDAD;
SELECT * FROM C##DW.BD2_DIM_ESTADIO;

--**********************************************************
--********** Prueba 08: Verificar Triggers de PK **********
-- Insertar sin clave y verificar que se genera automáticamente.
--**********************************************************
INSERT INTO C##DW.BD2_DIM_HORA(HORA) VALUES ('20:00');
SELECT * FROM C##DW.BD2_DIM_HORA WHERE HORA = '20:00';

--**********************************************************
--********** Prueba 09: Ejecutar PRC_CONSTRUYE_HECHOS(1) **********
-- Inserta en HECHOS si todas las claves existen; si no, en NO_HECHOS.
--**********************************************************
EXEC C##DW.PRC_CONSTRUYE_HECHOS(1);
SELECT * FROM C##DW.BD2_HECHOS;
SELECT * FROM C##PRODUCCION.BD2_NO_HECHOS;

--**********************************************************
--********** Prueba 10: Llenado de Seguimiento **********
-- Registra actividad de dimensión en tabla de seguimiento.
--**********************************************************
EXEC C##PRODUCCION.PRC_LLENA_SEGUIMIENTO('DIM_HORA');
SELECT * FROM C##PRODUCCION.BD2_SEGUIMIENTO WHERE DIMENSION = 'DIM_HORA';

--**********************************************************
--********** Prueba 11: Ejecutar PRC_CONSTRUYE_HECHOS(2) **********
-- Inserta desde NO_HECHOS sin validar claves nulas.
--**********************************************************
EXEC C##DW.PRC_CONSTRUYE_HECHOS(2);
SELECT * FROM C##DW.BD2_HECHOS;

--**********************************************************
--********** Prueba 12: Procesamiento Automático de Claves Faltantes **********
-- Detecta claves nulas en NO_HECHOS y ejecuta PRC_DIM_XXX(2).
--**********************************************************


EXEC C##DW.PRC_PROCESA_NOHECHOS;

-- Verificar si claves han sido llenadas al ejecutar de nuevo
EXEC C##DW.PRC_CONSTRUYE_HECHOS(1);
SELECT * FROM C##DW.BD2_HECHOS;
SELECT * FROM C##PRODUCCION.BD2_NO_HECHOS;

--**********************************************************
--********** Fin de las pruebas detalladas del proyecto **********
--**********************************************************
