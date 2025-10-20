#!/bin/bash

DATE_VAR="$(date +%Y%m%d)"
EXPORT_DATA=export_data

cd ${EXPORT_DATA}
pg_dump -h ${PGHOST_2} -p ${PGPORT_2} -U ${PGUSER_2} -d ${PGDATABASE_2} -n public > public_schema_backup.sql # pgs2 (public/eyedro)
tar czvf pg2-eyedro-pgdump-${DATE_VAR}.tgz public_schema_backup.sql

pg_dump -h ${PGHOST_2} -p ${PGPORT_2} -U ${PGUSER_2} -d ${PGDATABASE_2} -n weather > weather_schema_backup.sql # pgs2 (weather)

tar czvf weather-db-${DATE_VAR}.tgz weather_schema_backup.sql

cd ..
