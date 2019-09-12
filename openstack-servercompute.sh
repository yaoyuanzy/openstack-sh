#!/bin/bash
ip=$(ip -4 -f inet addr show ${eth} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/' | grep 168.61)
mysql -u root -pQuanjing_db2019 <<EOF
CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;
CREATE DATABASE placement;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'QJ_nova2019';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'QJ_nova2019';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'QJ_nova2019';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'QJ_nova2019';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'QJ_nova2019';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'QJ_nova2019';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY 'QJ_placement2019';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY 'QJ_placement2019';
flush privileges;
EOF
#创建对应的用户注册nova和placement的服务
export OS_USERNAME=admin
export OS_PASSWORD=quanjing
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://${ip}:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
openstack user create --domain default --password=quanjing nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://${ip}:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://${ip}:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://${ip}:8774/v2.1
openstack user create --domain default --password=quanjing placement
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public http://${ip}:8778
openstack endpoint create --region RegionOne placement internal http://${ip}:8778
openstack endpoint create --region RegionOne placement admin http://${ip}:8778
#开始安装glance的服务，并借助工具快速配置服务
yum install -y openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy \
    openstack-nova-scheduler openstack-nova-placement-api openstack-utils 
openstack-config --set  /etc/nova/nova.conf DEFAULT enabled_apis  osapi_compute,metadata
openstack-config --set  /etc/nova/nova.conf DEFAULT my_ip ${ip}
openstack-config --set  /etc/nova/nova.conf DEFAULT use_neutron  true 
openstack-config --set  /etc/nova/nova.conf DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver
openstack-config --set  /etc/nova/nova.conf DEFAULT transport_url  rabbit://openstack:quanjing@${ip}
openstack-config --set  /etc/nova/nova.conf api_database connection  mysql+pymysql://nova:QJ_nova2019@${ip}/nova_api
openstack-config --set  /etc/nova/nova.conf database connection  mysql+pymysql://nova:QJ_nova2019@${ip}/nova
openstack-config --set  /etc/nova/nova.conf placement_database connection  mysql+pymysql://placement:QJ_placement2019@${ip}/placement
openstack-config --set  /etc/nova/nova.conf api auth_strategy  keystone 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_url  http://${ip}:5000/v3
openstack-config --set  /etc/nova/nova.conf keystone_authtoken memcached_servers  ${ip}:11211
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_type  password
openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_domain_name  default 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken user_domain_name  default
openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_name  service 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken username  nova 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken password  quanjing
openstack-config --set  /etc/nova/nova.conf vnc enabled true
openstack-config --set  /etc/nova/nova.conf vnc server_listen '$my_ip'
openstack-config --set  /etc/nova/nova.conf vnc server_proxyclient_address '$my_ip'
openstack-config --set  /etc/nova/nova.conf glance api_servers  http://${ip}:9292
openstack-config --set  /etc/nova/nova.conf oslo_concurrency lock_path  /var/lib/nova/tmp 
openstack-config --set  /etc/nova/nova.conf placement region_name RegionOne
openstack-config --set  /etc/nova/nova.conf placement project_domain_name Default
openstack-config --set  /etc/nova/nova.conf placement project_name service
openstack-config --set  /etc/nova/nova.conf placement auth_type password
openstack-config --set  /etc/nova/nova.conf placement user_domain_name Default
openstack-config --set  /etc/nova/nova.conf placement auth_url http://${ip}:5000/v3
openstack-config --set  /etc/nova/nova.conf placement username placement
openstack-config --set  /etc/nova/nova.conf placement password quanjing
openstack-config --set  /etc/nova/nova.conf scheduler discover_hosts_in_cells_interval 120
#最后一项配置是服务端的计算节点多久去检查一次新加入的host主机信息，可以自动将安装好的计算节点主机加入集群，修改为120s
grep "^[a-z]" /etc/nova/nova.conf
cat <<EOF >>/etc/httpd/conf.d/00-nova-placement-api.conf

<Directory /usr/bin>
   <IfVersion >= 2.4>
      Require all granted
   </IfVersion>
   <IfVersion < 2.4>
      Order allow,deny
      Allow from all
   </IfVersion>
</Directory>
EOF
systemctl restart httpd
su -s /bin/sh -c "nova-manage api_db sync" nova
mysql -u root -pQuanjing_db2019 -e "use nova_api;show tables;"
mysql -u root -pQuanjing_db2019 -e "use placement;show tables;"
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova
#执行会有2个警告无视即可
su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
mysql -u root -pQuanjing_db2019 -e "use nova_cell0;show tables;"
mysql -u root -pQuanjing_db2019 -e "use nova;show tables;"
#这两个数据库表信息应该是一样的 
systemctl enable openstack-nova-api.service openstack-nova-consoleauth.service \
openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl start openstack-nova-api.service openstack-nova-consoleauth.service \
openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl enable openstack-nova-api.service openstack-nova-consoleauth.service \
openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl status openstack-nova-api.service openstack-nova-consoleauth.service \
openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
