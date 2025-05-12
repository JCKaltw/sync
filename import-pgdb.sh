#!/bin/bash

source ~/ggmap
PGUI_DIR="$(ggdir pgui)"
DATE_VAR="$(date +%Y%m%d)"
EXPORT_DATA=export_data
cd ${EXPORT_DATA}

scp pg2:sync/${EXPORT_DATA}/pg2-pgdb-${DATE_VAR}.tgz .

gg pgui
rm -rf data
tar xvf ~/sync/${EXPORT_DATA}/pg2-pgdb-${DATE_VAR}.tgz

cd ~/sync/${EXPORT_DATA}
scp pg2:sync/${EXPORT_DATA}/pg2-pgdb-pgdump-${DATE_VAR}.tgz .
tar xvf pg2-pgdb-pgdump-${DATE_VAR}.tgz

psql -h ${PGHOST_3} -p ${PGPORT_3} -U ${PGUSER_3} -d ${PGDATABASE_3} -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" && psql -h ${PGHOST_3} -p ${PGPORT_3} -U ${PGUSER_3} -d ${PGDATABASE_3} -f public_schema_backup.sql

cd ..
