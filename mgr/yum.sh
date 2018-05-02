#!/bin/bash

yum -y install openssh-server openssh-clients
yum -y install libaio libaio-devel
yum -y install numactl numactl-devel
yum deplist mysql mysql-server | grep provider | awk '{print $2}' | sort | uniq | grep -v mysql | sed ':a;N;$!ba;s/\n/ /g' | xargs yum -y install
