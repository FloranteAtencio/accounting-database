### Edit crontab
crontab -e

### Add these lines:

### Daily backup at 2 AM
0 2 * * * /home/ran/git/erp-database/scripts/backup.sh

### Weekly test restore (Sunday at 3 AM)
0 3 * * 0 /home/ran/git/erp-database/scripts/test-restore.sh

### Daily disk check (every morning at 6 AM)
0 6 * * * /home/ran/git/erp-database/scripts/check-disk.sh

### Daily backup alert (every morning at 7 AM)
0 7 * * * /home/ran/git/erp-database/scripts/backup-alert.sh

### Weekly Partition of journals (Every Sunday Morning at 2 AM)
0 2 * * 0 docker exec -it erp_postgres psql -U erp_admin -d erp_db -c "Select partion_monthly_basis('Finance','journals');"

### Monthly Parition of AccountPayables (Every  morning at 2 AM)
0 2 1 * * docker exec -it erp_postgres psql -U erp_admin -d erp_db -c "Select partion_monthly_basis('Finance','ap_ext');"

### Monthly Parition of AccountReceivables (Every  morning at 2 AM)
0 2 1 * * docker exec -it erp_postgres psql -U erp_admin -d erp_db -c "Select partion_monthly_basis('Finance','ar_ext');"

### Monthly Parition of Inventoryaudits (Every  morning at 2 AM)
0 2 1 * * docker exec -it erp_postgres psql -U erp_admin -d erp_db -c  "Select partion_monthly_basis('Finance','inventory_audits');"
