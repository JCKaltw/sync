#!/bin/bash

DATE_VAR="$(date +%Y%m%d)"
EXPORT_DATA=export_data
cd ${EXPORT_DATA}

echo "Downloading from pg2..."
scp pg2:sync/${EXPORT_DATA}/pg2-purifi-pgdump-${DATE_VAR}.tgz .
tar xvf pg2-purifi-pgdump-${DATE_VAR}.tgz

echo "Importing purifi (pgs1) database public schema..."
psql -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} -d ${PGDATABASE} -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" && psql -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} -d ${PGDATABASE} -f public_schema_backup.sql

cd ..
