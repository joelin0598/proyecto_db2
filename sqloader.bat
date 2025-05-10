@echo off
echo Iniciando carga de datos con SQL*Loader...
sqlldr C##stage/stage123 control="D:\backup\Escritorio\Universidad\Semestre 7\DB2\Proyecto\importar_partidos.ctl" log="D:\backup\Escritorio\Universidad\Semestre 7\DB2\Proyecto\importar_partidos.log"
echo Carga finalizada. Presiona cualquier tecla para salir.
pause
