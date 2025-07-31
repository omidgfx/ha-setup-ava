# Failover Test Plan

- Power off node1
- Stop MySQL
- Disconnect enp0s8

## ✅ Failover Test Scenarios

| Scenario                                     | Action Taken                                                                 | Expected Result                                                                                     | Actual Result ✅/❌ |
|---------------------------------------------|-------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|-------------------|
| Primary node (node1) shutdown               | Powered off node1                                                            | node2 becomes MASTER, VIP assigned to node2, services up                                            | ✅                 |
| MariaDB service crash on node1             | `systemctl stop mariadb` on node1                                           | node2 becomes MASTER, VIP moves to node2, node2 serves web and DB                                   | ✅                 |
| Galera becomes non-primary on node1        | Manually set Galera cluster to non-Primary state                            | node2 becomes MASTER due to health check fail                                                       | ✅                 |
| DRBD loses "Primary" role on node1         | Demoted node1 to Secondary via DRBD                                         | node2 becomes MASTER, takes over DRBD and VIP                                                       | ✅                 |
| Disconnect enp0s8 network on node1         | `ip link set enp0s8 down` on node1                                          | node2 becomes MASTER, VIP transferred cleanly                                                       | ✅                 |
| Reconnect node1 to cluster                 | Reboot node1 or `ip link set enp0s8 up`                                     | node1 rejoins as BACKUP, no conflict, VIP remains on node2                                          | ✅                 |
| DRBD sync conflict or split-brain          | Manually simulate conflict (not done here)                                  | Must be manually resolved using `drbdadm --discard-my-data` or `--overwrite-data-of-peer`           | ❌ Not tested      |
