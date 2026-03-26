# Backup Strategy for Single Server Setup

## Overview
- **Frequency**: Daily backups
- **Storage**: Internal + External drive
- **Retention**: 30 days
- **Compression**: Gzip
- **Testing**: Weekly restore test
- **Alerts**: Email notifications

## Backup Process
1. `backup.sh` runs daily at 2 AM
2. Creates SQL dump
3. Compresses with gzip
4. Copies to external drive
5. Cleans up old backups (>30 days)

## Restore Process
1. Use `restore.sh <backup-file>`
2. Example: `./restore.sh erp_2026-03-20_02-00-00.sql.gz`

## Test Restore
- Runs weekly on Sundays
- Restores to `test_restore` database
- Verifies data integrity

## Monitoring
- Disk space checked daily
- Backup success alerts sent via email

## Recovery Steps
1. Mount external drive
2. Run `restore.sh` with latest backup
3. Verify data
4. Restart application
