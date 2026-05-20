#!/bin/bash

SOURCE_DIR="$HOME"
BACKUP_DIR="$HOME/backups"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

mkdir -p $BACKUP_DIR

tar -czf $BACKUP_DIR/home-backup-$TIMESTAMP.tar.gz $SOURCE_DIR

echo "Backup completed successfully."

echo "Backup stored at:"
echo "$BACKUP_DIR/home-backup-$TIMESTAMP.tar.gz"
