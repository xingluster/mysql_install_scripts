#!/bin/bash

######################################
#
# add rsa key to remote host authorized_keys
# $1 - password of root
# $N - remote host addresses
#
######################################

if [ "$#" -lt 2 ]; then
	echo usage $0 password host_ip...
	exit
fi

password=$1

shift

source ./dist.sh

# component needed
if [ $MGR_PM = "yum" ]; then
	yum -y install openssh-clients sshpass
fi

for i in $*
do
	ssh-keygen -R $i
	sshpass -p $password ssh-copy-id -o StrictHostKeyChecking=no root@$i

	if [ "$?" == 0 ]; then
		echo ========== [$i] operation [copy key] success
	else
		echo ========== [$i] operation [copy key] failure
	fi
done
