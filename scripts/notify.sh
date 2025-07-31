#!/bin/bash

TYPE=$1
NAME=$2
STATE=$3

TOKEN="1677765890:UPocIwrAoA8h4bpy4U5rZ6eOsFcY3V3rpZH4kbh9"
CHAT_ID="@ava_ha_notifs"
MESSAGE="Keepalived notification on $NAME: State changed to $STATE (Type: $TYPE)"

echo "$(date '+%Y-%m-%d %H:%M:%S') - $MESSAGE" >> /var/log/keepalived_failover.log

curl -s -X POST https://tapi.bale.ai/bot$TOKEN/sendMessage -d chat_id=$CHAT_ID -d text="$MESSAGE" > /dev/null