# Backup System
Create a backup script:
```
# in this folder
cp templates/backup.template ./yourname.backup.sh
# edit the backup script
chmod +x yourname.backup.sh
```

Add cron:
```
# need sudo if zipping root level folders
sudo crontab -e

0 0 * * * /home/USER/server_tools/backup-scripts/backup.sh >> ~/.logs/backup-system.log
```
