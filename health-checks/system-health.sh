#!/bin/bash

echo "===== SYSTEM HEALTH CHECK ====="

echo ""

echo "Hostname:"
hostname

echo ""

echo "Uptime:"
uptime

echo ""

echo "Memory Usage:"
free -h

echo ""

echo "Disk Usage:"
df -h

echo ""

echo "Running Processes:"
ps aux --sort=-%mem | head

echo ""

echo "===== HEALTH CHECK COMPLETE ====="
