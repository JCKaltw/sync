#!/bin/bash
source ~/ggmap
PGUI_DIR="$(ggdir pgui)"
DATE_VAR="$(date +%Y%m%d)"
EXPORT_DATA=export_data
cd ${EXPORT_DATA}

echo "Downloading from pg2..."
scp pg2:sync/${EXPORT_DATA}/pg2-pgdb-${DATE_VAR}.tgz .
scp pg2:sync/${EXPORT_DATA}/pg2-pgdb-pgdump-${DATE_VAR}.tgz .

echo "Uploading to pg4..."
scp pg2-pgdb-${DATE_VAR}.tgz pg2-pgdb-pgdump-${DATE_VAR}.tgz pg4:sync
