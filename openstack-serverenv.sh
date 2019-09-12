#!/bin/bash
ip=$(ip -4 -f inet addr show ${eth} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/' | grep 168.61)

#1.mysql的安装和初始化
wget http://repo.mysql.com/mysql57-community-release-el7-8.noarch.rpm
rpm -ivh mysql57-community-release-el7-8.noarch.rpm
yum -y install mysql-server python2-PyMySQL
cat <<EOF >/etc/my.cnf
[mysqld]
bind-address = 0.0.0.0
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
tmp_table_size = 512M
max_heap_table_size = 512M
expire_logs_days=7
binlog-format=ROW
log-slave-updates=true
gtid-mode=on
enforce-gtid-consistency=true
sync-master-info=1
slave-parallel-workers=2
server-id=10
log-bin=mysql-bin.log

# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0
character_set_server=utf8
collation-server = utf8_general_ci
init_connect='SET NAMES utf8'

log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
EOF
sed -i s/0.0.0.0/${ip}/g /etc/my.cnf
mkdir -p /var/lib/mysql
chown mysql:mysql -R /var/lib/mysql
systemctl enable mysqld
systemctl start mysqld
systemctl status mysqld
#cat /var/log/mysqld.log | grep password >/root/mypass
old=`cat /var/log/mysqld.log | grep password |head -1| awk '{print $11}'`
mysql -uroot -p$old --connect-expired-password <<EOF
ALTER USER USER() IDENTIFIED BY 'Quanjing_db2019';
use mysql;
select host,user,authentication_string from user;
grant all privileges  on *.* to root@'%' identified by "Quanjing_db2019";
flush privileges;
select host,user,authentication_string from user;
EOF
mysql -uroot -pQuanjing_db2019 -e "select version();"
echo -e "Mysql install done,listen on ${ip} and port 3306,pass is Quanjing_db2019"

#2.rabbitmq消息队列的安装和初始化
yum install -y rabbitmq-server
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service
#添加用户赋予读写的权限，启用web的管理插件端口http://192.168.61.230:15672
rabbitmqctl add_user openstack quanjing
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
rabbitmqctl set_permissions -p "/" openstack ".*" ".*" ".*"
rabbitmq-plugins enable rabbitmq_management
#rabbitmq-plugins list 
systemctl restart rabbitmq-server.service
#将openstack用户提升为管理员，干掉默认的guest账户，默认密码是guest拥有管理员权限
rabbitmqctl  set_user_tags openstack administrator
rabbitmqctl delete_user guest
echo -e "rabbitmq install done,you can visit webmag http://${ip}:15672 with user openstack pass quanjing"

#3.memcached缓存安装和初始化,跟redis一样存在安全的问题，还要监听地址要合理修改,controller需要在hosts文件中有对应的IP不然加上后启动会找不到监听地址自动退出的
yum install -y memcached python-memcached
#/usr/bin/memcached -p 11211 -u memcached -m 1024 -c 1024 -l 127.0.0.1,controller -vv 调式启动
sed -i "s/^CACHESIZE.*/CACHESIZE=\"1024\"/g" /etc/sysconfig/memcached
sed -i "s/^OPTIONS.*/OPTIONS=\"-l ${ip}\"/g" /etc/sysconfig/memcached
systemctl enable memcached.service
systemctl start memcached.service
echo -e "memcached install done,you can telnet ${ip} 11211 to test"

#4.etcd分布式KV存储集群安装和初始化,跟zk有点类似但是使用场景不一样
yum install -y etcd
cat <<EOF >/etc/etcd/etcd.conf
#[Member]
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="http://127.0.0.1:2380"
ETCD_LISTEN_CLIENT_URLS="http://127.0.0.1:2379"
ETCD_NAME="controller"
#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://127.0.0.1:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://127.0.0.1:2379"
ETCD_INITIAL_CLUSTER="controller=http://127.0.0.1:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-quanjing"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF
sed -i "s/127.0.0.1/${ip}/g" /etc/etcd/etcd.conf
systemctl enable etcd
systemctl start etcd
echo -e "etcd install done,you can lean more to finsh this print!"
