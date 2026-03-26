## 🚀 Environment Setup (Ubuntu)

### 🔄 Update System

```bash
sudo apt update
sudo apt upgrade -y
```

## 🐳 Install Docker

```bash
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable"

sudo apt install docker-ce docker-ce-cli containerd.io -y
```

## Install Docker Composer
```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose
```

### ▶️ Enable Docker
```bash
sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker $USER
newgrp docker
```
### 📁 Create Mount Points
```bash
sudo mkdir /mnt/ssd_hot
sudo mkdir /mnt/hdd_cold
sudo chown postgres:postgres /mnt/ssd_hot /mnt/hdd_cold
sudo chmod 700 /mnt/ssd_hot /mnt/hdd_cold
```

### 🔗 Mount Drives
```bash
mount {ssd_location} /mnt/ssd_hot
mount {hdd_location} /mnt/hdd_cold
```

### 🧠 Create Tablespaces

Inside container:

```sql
CREATE TABLESPACE hotspace LOCATION '/mnt/ssd_hot';
CREATE TABLESPACE coldspace LOCATION '/mnt/hdd_cold';
```


### 🔥 Fire wall 🔥
```bash

sudo apt install ufw

sudo ufw enable
sudo ufw allow ssh
sudo ufw deny 5432
```

### 🔐 Use Environment File (DON’T hardcode passwords)
Create .env file:
```bash
nano .env
```

```bash
POSTGRES_PASSWORD=StrongPassword123!
POSTGRES_DB=erp_db
POSTGRES_USER=erp_admin
```

### 💾 Backup Setup (DO THIS NOW)

Create backup script:
```bash
nano backup.sh
```

```bash
#!/bin/bash
docker exec erp_postgres pg_dump -U erp_admin erp_db > /backup/erp_$(date +%F).sql
```
#### Make executable:
```bash
chmod +x backup.sh
```

#### Schedule daily backup:
```bash
crontab -e
```
Add:
```bash
7 2 * * * ~/git/Prod-database/backup.sh
```

### 🔐 Access PostgreSQL
```bash
docker exec -it erp_postgres psql -U erp_admin -d erp_db
```

Basic Performance Config Inside container:
```bash
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET work_mem = '4MB';
SELECT pg_reload_conf();
```

### Some Helpful Debuging commands

let's debug this systematically. Run these commands:

1. Check if container is running
```bash
docker ps | grep erp_postgres
```
2. Check initialization logs
```bash
docker logs erp_postgres
```
Look for error messages or initialization output.
3. Verify volume is mounted correctly
```bash
docker exec erp_postgres ls -la /docker-entrypoint-initdb.d/
Should show your .sql files.
```
4. Check if database was created
```bash
docker exec erp_postgres psql -U postgres -l
Should list erp_db if initialization ran.
```
5. Force fresh initialization
```bash
docker-compose down -v
docker-compose up -d
docker logs erp_postgres
```
