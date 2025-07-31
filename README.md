# High Availability Setup (Active-Standby)

## 📌 Architecture Overview

This setup uses two Debian-based nodes (node1 and node2) configured in an Active-Standby model to provide high availability using the following components:

- **Keepalived**: Manages the floating virtual IP (`192.168.56.200`)
- **MariaDB + Galera**: Database clustering and replication
- **DRBD**: Real-time block-level filesystem replication
- **Health Check Scripts**: Monitor DRBD, MariaDB, and Galera
- **Failover Logic**: Automatic IP takeover and DRBD primary switching upon failure

### 🖥️ Nodes
- `node1` → IP: `192.168.56.101` (Primary)
- `node2` → IP: `192.168.56.102` (Secondary)
- Shared VIP: `192.168.56.200`

---

## ⚙️ Setup Instructions

### 1. Network Configuration
Each node uses the `enp0s8` interface configured with static IPs:

```bash
auto enp0s8
iface enp0s8 inet static
address 192.168.56.101 # 192.168.56.102 on node2
netmask 255.255.255.0
```

### 2. DRBD
**Tool**: `drbd-utils`  
**Config file**: `/etc/drbd.d/r0.res`  
**Device**: `/dev/sdb` on both nodes

Key commands:

```bash
drbdadm create-md r0
drbdadm up r0
drbdadm -- --overwrite-data-of-peer primary r0  # on node1
mkfs.ext4 /dev/drbd0 && mount /dev/drbd0 /mnt/drbd
```

### 3. Galera + MariaDB
**Tool**: `mariadb-server`, `galera-4`  
**Config file**: `/etc/mysql/mariadb.conf.d/50-server.cnf`

Key parameters:

```ini
wsrep_on = ON
wsrep_provider = /usr/lib/galera/libgalera_smm.so
wsrep_cluster_address = gcomm://192.168.56.101,192.168.56.102
wsrep_cluster_name = my_cluster
wsrep_node_address = 192.168.56.101  # 192.168.56.102 on node2
wsrep_node_name = node1                # node2 on node2
wsrep_sst_method = rsync
```

### 4. Keepalived
**Tool**: `keepalived`  
**Config file**: `/etc/keepalived/keepalived.conf`

Key parameters:

- `priority 100` on node1 (MASTER), `90` on node2 (BACKUP)
- Health check scripts (`check_mysql.sh`, `check_galera.sh`, `check_drbd.sh`)
- Virtual IP: `192.168.56.200` bound to `enp0s8`
- Notification scripts for failover events

Example snippet from `keepalived.conf`:

```bash
vrrp_script chk_mysql {
    script "/etc/keepalived/check_mysql.sh"
    interval 3
    weight -20
}

vrrp_script chk_galera {
    script "/etc/keepalived/check_galera.sh"
    interval 3
    weight -20
}

vrrp_script chk_drbd {
    script "/etc/keepalived/check_drbd.sh"
    interval 3
    weight -20
}

vrrp_instance VI_1 {
    state MASTER
    interface enp0s8
    virtual_router_id 51
    priority 100
    advert_int 1
    notify /etc/keepalived/notify.sh
    authentication {
        auth_type PASS
        auth_pass secret123
    }
    virtual_ipaddress {
        192.168.56.200
    }
    track_script {
        chk_mysql
        chk_galera
        chk_drbd
    }
}
```

### 5. Health Check Scripts

Scripts located in `/etc/keepalived/`:

- `check_mysql.sh`:

```bash
#!/bin/bash
if systemctl is-active --quiet mariadb; then
    exit 0
else
    exit 1
fi
```

- `check_galera.sh`:

```bash
#!/bin/bash
STATUS=$(mysql -u root -e "SHOW STATUS LIKE 'wsrep_cluster_status';" 2>/dev/null | grep Primary)
if [ -z "$STATUS" ]; then
    exit 1
else
    exit 0
fi
```

- `check_drbd.sh`:

```bash
#!/bin/bash
drbd_status=$(cat /proc/drbd | grep -A 2 "cs:Connected" | grep "ro:Primary")
if [ -z "$drbd_status" ]; then
    exit 1
else
    exit 0
fi
```

### 6. Failover Behavior

| Event                             | Expected Outcome                                                   |
|----------------------------------|--------------------------------------------------------------------|
| node1 shuts down                 | node2 takes over VIP, becomes DRBD primary, mounts /mnt/drbd      |
| mariadb fails on node1           | node2 takes over VIP and services                                  |
| node1 returns to cluster         | node1 becomes backup, syncs via DRBD                               |
| manual DRBD switch on node1      | node1 can become primary after demoting node2 and mounting again   |

### 7. Testing Plan

Tested scenarios include:

- Power off node1  
- Killing `mariadb` service on node1  
- Disconnecting `enp0s8` interface on node1  

The system responded as expected, with failover happening cleanly, VIP moving, and data remaining consistent.

---

## 🌐 Bonus: Basic Web Service

A minimal PHP-based web service was deployed on the Active node, accessible through the floating virtual IP (`192.168.56.200`).

- The web service serves a simple status page confirming the availability of the service during failover.
- This ensures continuous service access even when the primary node fails and the VIP moves to the standby node.
- The web server runs on both nodes but is only actively serving on the primary node due to DRBD filesystem mount and VIP assignment.

**Location:** `/var/www/html/index.php`

Example `index.php` content:

```php
<?php
echo "HA Web Service is running on node " . gethostname();
?>
```

---

## 📣 Failover Event Logging and Notifications

Keepalived notification scripts were implemented to log failover events locally and send notifications via the Bale messaging platform.

- Notifications include the event type (MASTER, BACKUP, FAULT), the node name, and the state change details.
- Logs are saved in `/var/log/keepalived_failover.log` for audit and troubleshooting purposes.
- The notification script is triggered automatically by Keepalived via the `notify_master`, `notify_backup`, and `notify_fault` directives.

**Notify script location:** `/etc/keepalived/notify.sh`

`notify.sh` script content:

```bash
#!/bin/bash

TYPE=$1
NAME=$2
STATE=$3

TOKEN="1677765890:UPocIwrAoA8h4bpy4U5rZ6eOsFcY3V3rpZH4kbh9"
CHAT_ID="@ava_ha_notifs"
MESSAGE="Keepalived notification on $NAME: State changed to $STATE (Type: $TYPE)"

echo "$(date '+%Y-%m-%d %H:%M:%S') - $MESSAGE" >> /var/log/keepalived_failover.log

curl -s -X POST https://tapi.bale.ai/bot$TOKEN/sendMessage -d chat_id=$CHAT_ID -d text="$MESSAGE" > /dev/null
```

---

## 🧠 Author: Pejman
