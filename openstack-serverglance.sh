#!/bin/bash
ip=$(ip -4 -f inet addr show ${eth} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/' | grep 168.61)
mysql -u root -pQuanjing_db2019 <<EOF
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'QJ_glance2019';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'QJ_glance2019';
flush privileges;
EOF
#加一个判断如果输出是admin也就是当前的变量是管理员才能执行如下的内容
export OS_USERNAME=admin
export OS_PASSWORD=quanjing
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://${ip}:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
openstack user create --domain default --password=quanjing glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://${ip}:9292
openstack endpoint create --region RegionOne image internal http://${ip}:9292
openstack endpoint create --region RegionOne image admin http://${ip}:9292
#开始安装glance的服务，并借助工具快速配置服务
yum install -y openstack-glance python-glance python-glanceclient openstack-utils 
openstack-config --set  /etc/glance/glance-api.conf database connection  mysql+pymysql://glance:QJ_glance2019@${ip}/glance
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken www_authenticate_uri http://${ip}:5000
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_url http://${ip}:5000
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken memcached_servers  ${ip}:11211
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_type password
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken project_domain_name Default
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken user_domain_name Default
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken project_name service 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken username glance
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken password quanjing
openstack-config --set  /etc/glance/glance-api.conf paste_deploy flavor keystone
openstack-config --set  /etc/glance/glance-api.conf glance_store stores  file,http
openstack-config --set  /etc/glance/glance-api.conf glance_store default_store file
openstack-config --set  /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/
openstack-config --set  /etc/glance/glance-registry.conf database connection mysql+pymysql://glance:QJ_glance2019@${ip}/glance
openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken www_authenticate_uri http://${ip}:5000
openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken auth_url http://${ip}:5000
openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken memcached_servers ${ip}:11211
openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken auth_type password
openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken project_domain_name Default
openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken user_domain_name Default
openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken project_name service
openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken username glance
openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken password quanjing
openstack-config --set  /etc/glance/glance-registry.conf paste_deploy flavor keystone
#检查配置是否正确
grep '^[a-z]' /etc/glance/glance-api.conf 
grep '^[a-z]' /etc/glance/glance-registry.conf 
su -s /bin/sh -c "glance-manage db_sync" glance
mysql -u root -pQuanjing_db2019 -e "use glance;show tables;"
#数据库表信息OK后启动服务
systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl start openstack-glance-api.service openstack-glance-registry.service
#上传镜像进行验证
#cd /root
#wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
#openstack image create "cirros" --file cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public
