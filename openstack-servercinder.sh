#!/bin/bash
ip=$(ip -4 -f inet addr show ${eth} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/' | grep 168.61)
mysql -u root -pQuanjing_db2019 <<EOF
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'QJ_cinder2019';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'QJ_cinder2019';
flush privileges;
EOF
#创建对应的用户注册cinder的服务
export OS_USERNAME=admin
export OS_PASSWORD=quanjing
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://${ip}:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
openstack user create --domain default --password=quanjing cinder
openstack role add --project service --user cinder admin
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
openstack endpoint create --region RegionOne volumev2 public http://${ip}:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 internal http://${ip}:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 admin http://${ip}:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 public http://${ip}:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 internal http://${ip}:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 admin http://${ip}:8776/v3/%\(project_id\)s
#开始安装cinder的服务，并借助工具快速配置服务
yum install -y openstack-cinder 
openstack-config --set  /etc/cinder/cinder.conf database connection  mysql+pymysql://cinder:QJ_cinder2019@${ip}/cinder
openstack-config --set  /etc/cinder/cinder.conf DEFAULT transport_url  rabbit://openstack:quanjing@${ip}
openstack-config --set  /etc/cinder/cinder.conf DEFAULT auth_strategy  keystone 
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken www_authenticate_uri  http://${ip}:5000
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken auth_url  http://${ip}:5000
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken memcached_servers  ${ip}:11211
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken auth_type  password
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken project_domain_name  default 
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken user_domain_name  default
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken project_name  service 
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken username  cinder
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken password  quanjing
openstack-config --set  /etc/cinder/cinder.conf DEFAULT my_ip ${ip}
openstack-config --set  /etc/cinder/cinder.conf oslo_concurrency lock_path  /var/lib/nova/tmp 
egrep -v "^#|^$" /etc/cinder/cinder.conf
su -s /bin/sh -c "cinder-manage db sync" cinder
mysql -u root -pQuanjing_db2019 -e "use cinder;show tables;"
openstack-config --set  /etc/nova/nova.conf cinder os_region_name  RegionOne
systemctl restart openstack-nova-api.service
systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service
