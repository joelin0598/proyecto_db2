@echo off
echo Iniciando carga de datos con SQL*Loader...
sqlldr C##stage/stage123 control="C:\proyecto_db2\importar_partidos.ctl" log="C:\proyecto_db2\importar_partidos.log"
echo Carga finalizada. Presiona cualquier tecla para salir.
pause
