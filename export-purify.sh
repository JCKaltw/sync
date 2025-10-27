#!/bin/bash

DATE_VAR="$(date +%Y%m%d)"
EXPORT_DATA=export_data

cd ${EXPORT_DATA}
pg_dump -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} -d ${PGDATABASE} -n public > public_schema_backup.sql # pgs1 (purifi)
tar czvf pg2-purifi-pgdump-${DATE_VAR}.tgz public_schema_backup.sql

cd ..
