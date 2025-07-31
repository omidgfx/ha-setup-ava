resource r0 {
    protocol C;
    on node1 {
        device /dev/drbd0;
        disk /dev/sdb;
        address 192.168.56.101:7789;
        meta-disk internal;
    }
    on node2 {
        device /dev/drbd0;
        disk /dev/sdb;
        address 192.168.56.102:7789;
        meta-disk internal;
    }
}