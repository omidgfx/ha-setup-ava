#!/bin/bash

STATUS=$(mysql -u root -e "SHOW STATUS LIKE 'wsrep_cluster_status';" 2>/dev/null | grep Primary)

if [ -z "$STATUS" ]; then
    exit 1
else
    exit 0
fi