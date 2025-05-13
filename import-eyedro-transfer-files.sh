#!/bin/bash

DATE_VAR="$(date +%Y%m%d)"
EXPORT_DATA=export_data
cd ${EXPORT_DATA}

echo "Downloading from pg2..."
scp pg2:sync/${EXPORT_DATA}/pg2-eyedro-pgdump-${DATE_VAR}.tgz pg2:sync/${EXPORT_DATA}/weather-db-${DATE_VAR}.tgz .

echo "Uploading to pg4..."
scp pg2-eyedro-pgdump-${DATE_VAR}.tgz weather-db-${DATE_VAR}.tgz pg4:sync/${EXPORT_DATA}

cd ..
