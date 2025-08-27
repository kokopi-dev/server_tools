#!/bin/bash
#func_check_rsync() {
#    command -v rsync >/dev/null 2>&1
#}

#if ! func_check_rsync; then
#    echo -e "rsync not found"
#    exit 1
#fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to the script's directory
cd "$SCRIPT_DIR" || {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed to change to script directory: $SCRIPT_DIR"
    exit 1
}

for backup_script in *.backup.sh; do
    [ -f "$backup_script" ] || continue

    if bash "$backup_script"; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ran $backup_script..."
    else
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Errored $backup_script..."
    fi
done

# send backups to offsite
for backup_tar in backups/*_backup.tar.gz; do
done
