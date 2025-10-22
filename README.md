# sync

## Database Export/Import Workflow

### Overview

This directory contains scripts for exporting database snapshots from the production environment (pg2) and importing them locally to your Mac for testing purposes.

### Workflow

#### 1. Export (Run on pg2)

The export scripts are executed on the **pg2 remote host** where the live databases are running. They create PostgreSQL dumps and package them into dated tarball files.

**Available export scripts:**
- `export-purifi.sh` - Exports the purifi database (pgs1)
- `export-eyedro.sh` - Exports the eyedro database with both public and weather schemas (pgs2)
- `export-pgdb.sh` - Exports the pgdb database and data directory (pgs3)

**Location on pg2:** `~/sync/export_data/`

#### 2. Import (Run on Mac)

The import scripts are executed on your **Mac** to download the export files from pg2 and restore them to local PostgreSQL instances for testing.

**Available import scripts:**
- `import-purifi.sh` - Imports the purifi database to local pgs1
- `import-eyedro.sh` - Imports the eyedro database to local pgs2
- `import-pgdb.sh` - Imports the pgdb database to local pgs3

### Transfer File Naming Convention

All transfer files use a consistent naming pattern that includes:
- Source identifier (`pg2-`)
- Service/database name
- Type of backup
- Date stamp in `YYYYMMDD` format

#### Pattern: `pg2-<service>-<type>-YYYYMMDD.tgz`

#### Examples

**Purifi:**
- `pg2-purifi-pgdump-20251022.tgz` - PostgreSQL dump of public schema

**Eyedro:**
- `pg2-eyedro-pgdump-20251022.tgz` - PostgreSQL dump of public schema
- `weather-db-20251022.tgz` - PostgreSQL dump of weather schema

**PGDB:**
- `pg2-pgdb-20251022.tgz` - Data directory files
- `pg2-pgdb-pgdump-20251022.tgz` - PostgreSQL dump of public schema

### Usage

#### On pg2 (Export)

```bash
cd ~/sync
./export-purifi.sh   # or
./export-eyedro.sh   # or
./export-pgdb.sh
```

This creates dated tarball files in `~/sync/export_data/`

#### On Mac (Import)

```bash
cd ~/sync
./import-purifi.sh   # or
./import-eyedro.sh   # or
./import-pgdb.sh
```

This will:
1. Download the dated tarball from pg2 via scp
2. Extract the SQL dump file(s)
3. Drop and recreate the schema(s)
4. Restore the database snapshot

### Environment Variables

Each database uses specific environment variables for connection:

**Purifi (pgs1):**
- `PGHOST`, `PGPORT`, `PGUSER`, `PGDATABASE`

**Eyedro (pgs2):**
- `PGHOST_2`, `PGPORT_2`, `PGUSER_2`, `PGDATABASE_2`

**PGDB (pgs3):**
- `PGHOST_3`, `PGPORT_3`, `PGUSER_3`, `PGDATABASE_3`

Ensure these are properly configured in your environment before running the scripts.

### Notes

- The date variable `${DATE_VAR}` is set to the current date when the export script runs
- Import scripts expect the same date-stamped files (run export and import on the same day)
- All schemas are dropped and recreated during import to ensure a clean restore
- The `export_data` directory is the working location for all transfer files
