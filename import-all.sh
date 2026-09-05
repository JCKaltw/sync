#!/bin/bash
./import-eyedro.sh
./import-pgdb.sh
./import-purify.sh

# Retention: keep the newest 2 dated exports of each family, delete older.
KEEP=2
cd export_data
for pat in 'pg2-eyedro-pgdump-*.tgz' 'pg2-purifi-pgdump-*.tgz' 'pg2-pgdb-pgdump-*.tgz' 'weather-db-*.tgz'; do
  ls -t $pat 2>/dev/null | tail -n +$((KEEP+1)) | xargs -r rm -v
done
# pg2-pgdb-*.tgz also matches the pgdump family; exclude it
ls -t pg2-pgdb-*.tgz 2>/dev/null | grep -v pgdump | tail -n +$((KEEP+1)) | xargs -r rm -v
cd ..
df -h /
