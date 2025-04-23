#!/bin/bash
source ~/ggmap
PGUI_DIR="$(ggdir pgui)"
DATE_VAR="$(date +%Y%m%d)"
EXPORT_DATA=export_data

echo "tar czvf pg2-pgdb-${DATE_VAR}.tgz ${PGUI_DIR}/data/*"
gg pgui
tar czvf ~/sync/${EXPORT_DATA}/pg2-pgdb-${DATE_VAR}.tgz data/*

cd ~/sync/${EXPORT_DATA}

pg_dump -h ${PGHOST_3} -p ${PGPORT_3} -U ${PGUSER_3} -d ${PGDATABASE_3} -n public > public_schema_backup.sql # pgs3 (pgdb)
tar czvf pg2-pgdb-pgdump-${DATE_VAR}.tgz public_schema_backup.sql

cd ..
