#!/bin/bash

if systemctl is-active --quiet mariadb; then
    exit 0
else
    exit 1
fi