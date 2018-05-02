#!/bin/bash

#########################################
#
# Install MqSQL Group Replication
#
# $1 - install media file
# $2 - version of mysql
# $3 - port of mysql
# $4 - inner port of group replication
# $5 - profile directory for mysql
# $6 - data directory for mysql
# $7 - server ip list
#
#########################################

if [ $# -lt 7 ]; then
	echo Error: number of parameter can not less than 7
	echo Usage: $0 install_file version client_port mgr_port profile_dir data_dir server_ip...
	exit
fi

mysql_install_media=$1
version=$2
client_port=$3
mgr_port=$4
profile_dir=$5
data_dir=$6

# check file exist
if [ ! -f $mysql_install_media ];then
	echo ERROR: File $mysql_install_media not exist
	exit;
fi

file_name=${mysql_install_media##*/}

if [[ ! $file_name =~ .+\.tar\.gz$ ]]; then
	echo ERROR: mysql_install_media only support tar.gz
	exit;
fi

echo ============================================================
echo ========== install media for MySQL: $mysql_install_media
echo ========== version for MySQL: $version
echo ========== port for MySQL client: $client_port
echo ========== port for MySQL Group Replication: $mgr_port
echo ========== profile directory for MySQL: $profile_dir
echo ========== data directory for MySQL: $data_dir

# shift for server ip list
for i in {1..6}
do
	shift;
done

if [ $# -gt 9 ]; then
	echo ERROR: server list count can not exceed 9
	exit;
fi

source ./dist.sh

# component needed
if [ $MGR_PM = "yum" ]; then
	yum -y install openssh-clients sshpass
fi

echo
echo ========== echo ========== server list: $*
echo ============================================================
echo
echo ========== config hosts for each other: $*
	./hosts.sh $*
echo ========== config hosts for each other done!

mysql_install_base=/opt/mysql-$version
echo ========== target mysql_install_base: $mysql_install_base

# remote tmp dir for place
tmp_dir=/tmp/installmgr$RANDOM

server_id=0
uuid=`uuid`

# set MGR variables
group_replication_group_seeds=
group_replication_ip_whitelist=

for i in $*
do
	if [ ! $group_replication_group_seeds ]; then
		group_replication_group_seeds=$i:$mgr_port
	else
		group_replication_group_seeds=$group_replication_group_seeds,$i:$mgr_port
	fi
	if [ ! $group_replication_ip_whitelist ]; then
		group_replication_ip_whitelist=$i
	else
		group_replication_ip_whitelist=$group_replication_ip_whitelist,$i
	fi
done

for i in $*
do
	echo ========== [$i] install openssh required

		ssh root@$i "yum -y install openssh-server openssh-clients"

	echo ========== [$i] install openssh required done!



	echo ========== [$i] create tmp_dir

		echo ========== [$i] tmp_dir: $tmp_dir
		ssh root@$i "mkdir -p $tmp_dir"

	echo ========== [$i] create tmp_dir done!



	echo ========== [$i] install mysql requirements files

		scp yum.sh root@$i:$tmp_dir
		ssh root@$i "cd $tmp_dir; chmod +x yum.sh; ./yum.sh"

	echo ========== [$i] install mysql requirements files done!



	echo ========== [$i] create mysql user "&" group

		scp user.sh root@$i:$tmp_dir
		ssh root@$i "cd $tmp_dir; chmod +x user.sh; ./user.sh"

	echo ========== [$i] create mysql user "&" group done!



	echo ========== [$i] copy mysql

		scp $mysql_install_media root@$i:$tmp_dir/$file_name
		ssh root@$i "cd $tmp_dir; tar xf $file_name -C /opt/;"
		ssh root@$i "cd /opt; mv ${file_name%.*.*} $mysql_install_base; chown -R mysql.mysql $mysql_install_base"

	echo ========== [$i] copy mysql done!


	echo ========== [$i] install mysql

		server_id=$((server_id+1))
		weight=$((10-server_id))
		curr_ip=$i

		cat my.cnf.template | sed "s/{{client_port}}/$client_port/g" \
							| sed "s/{{mgr_port}}/$mgr_port/g" \
							| sed "s/{{uuid}}/$uuid/g" \
							| sed "s/{{server_id}}/$server_id/g" \
							| sed "s/{{weight}}/$weight/g" \
							| sed "s/{{curr_ip}}/$curr_ip/g" \
							| sed "s/{{group_replication_group_seeds}}/$group_replication_group_seeds/g" \
							| sed "s/{{group_replication_ip_whitelist}}/$group_replication_ip_whitelist/g" \
							| sed "s:{{mysql_install_base}}:$mysql_install_base:g" \
							| sed "s:{{data_dir}}:$data_dir:g" \
		> my.cnf

		ssh root@$i "mkdir -p $profile_dir"
		scp my.cnf root@$i:$profile_dir/my.cnf
		ssh root@$i "chown -R mysql:mysql $profile_dir"
		echo ========== [$i] my.cnf created

		# remove tmp file
		rm ./my.cnf

		command="$mysql_install_base/bin/mysqld --no-defaults --user=mysql --basedir=$mysql_install_base --datadir=$data_dir --initialize-insecure"
		echo ========== [$i] exec command: $command
		ssh root@$i $command
		echo ========== [$i] database created

		command="$mysql_install_base/bin/mysqld_safe --defaults-file=$profile_dir/my.cnf >/dev/null 2>&1 &"
		echo ========== [$i] exec command: $command
		ssh root@$i $command
		echo ========== [$i] database started

		# wait mysql instance start complete
		sleep 3

		echo ========== [$i] create database user "&" privileges
		scp db_user.sql root@$i:$tmp_dir
		command="$mysql_install_base/bin/mysql -uroot -h127.0.0.1 -P3316 < $tmp_dir/db_user.sql"
		echo ========== [$i] exec command: $command
		ssh root@$i $command
		echo ========== [$i] create database user "&" privileges done!

		if [ ! $master_node ]; then
			echo ========== [$i] is master
			scp start_mgr_master.sql root@$i:$tmp_dir/start_mgr.sql
			master_node=$i
		else
			echo ========== [$i] is slave
			scp start_mgr_slave.sql root@$i:$tmp_dir/start_mgr.sql
		fi

		echo ========== [$i] start mgr
		command="$mysql_install_base/bin/mysql -uroot -h127.0.0.1 -P3316 -pPassw0rd! < $tmp_dir/start_mgr.sql"
		echo ========== [$i] exec command: $command
		ssh root@$i $command
		echo ========== [$i] start mgr done!

		echo ========== [$i] clean tmp_dir: $tmp_dir
		command="rm -rf $tmp_dir"
		echo ========== [$i] exec command: $command
		ssh root@$i $command
		echo ========== [$i] clean tmp_dir done!

	echo ========== [$i] install mysql done!

done

echo
echo ============================================================
echo ==========  Congratulations! MGR INSTALL SUCCESS! ==========
echo ==========  Install MqSQL Group Replication Done! ==========
echo ============================================================
echo
