#!/bin/bash

DATE_VAR="$(date +%Y%m%d)"
EXPORT_DATA=export_data
cd ${EXPORT_DATA}

echo "Downloading from pg2..."
scp pg2:sync/${EXPORT_DATA}/pg2-eyedro-pgdump-${DATE_VAR}.tgz pg2:sync/${EXPORT_DATA}/weather-db-${DATE_VAR}.tgz .
tar xvf pg2-eyedro-pgdump-${DATE_VAR}.tgz

echo "Importing eyedro (pgs2) database public schema..."
psql -h ${PGHOST_2} -p ${PGPORT_2} -U ${PGUSER_2} -d ${PGDATABASE_2} -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" && psql -h ${PGHOST_2} -p ${PGPORT_2} -U ${PGUSER_2} -d ${PGDATABASE_2} -f public_schema_backup.sql

echo "Importing eyedro (pgs2) database weather schema..."
tar xvf weather-db-${DATE_VAR}.tgz
psql -h ${PGHOST_2} -p ${PGPORT_2} -U ${PGUSER_2} -d ${PGDATABASE_2} -c "DROP SCHEMA weather CASCADE; CREATE SCHEMA weather;" && psql -h ${PGHOST_2} -p ${PGPORT_2} -U ${PGUSER_2} -d ${PGDATABASE_2} -f weather_schema_backup.sql

cd ..
