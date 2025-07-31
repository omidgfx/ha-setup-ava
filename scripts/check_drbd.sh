#!/bin/bash

drbd_status=$(cat /proc/drbd | grep -A 2 "cs:Connected" | grep "ro:Primary")

if [ -z "$drbd_status" ]; then
    exit 1
else
    exit 0
fi