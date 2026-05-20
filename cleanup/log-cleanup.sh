#!/bin/bash

LOG_DIR="/var/log"
DAYS=7

echo "Starting log cleanup..."

find $LOG_DIR -type f -name "*.log" -mtime +$DAYS -exec rm -f {} \;

echo "Old log files older than $DAYS days removed."

echo "Log cleanup completed."
