#!/bin/bash

######################################
#
# add hostname to each other
#
# $1 - host addr
# $2 - host addr
# $N...
# 
######################################

for i in $*
do
	remotehostname=`ssh root@$i "hostname"`
	echo prepare add $i:$remotehostname to other nodes
	for j in $*
	do
		if [ $j == $i ]; then
			continue;
		fi
		
		remoteIp=`ssh root@$j "ping $remotehostname -c1 | sed '1{s/[^(]*(//;s/).*//;q}'"`

		if [ ! $remoteIp ]; then
			remoteIp="none"
		fi

		if [ $remoteIp = $i ]; then
			echo $i:$remotehostname already contained in $j:/etc/hosts
		else
			ssh root@$j "echo $i $remotehostname >> /etc/hosts"
			echo add [$i:$remotehostname] to $j:/etc/hosts
		fi
	done
done
