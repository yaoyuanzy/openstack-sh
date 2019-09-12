#!/bin/bash
ip=$(ip -4 -f inet addr show ${eth} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/' | grep 168.61)
mysql -u root -pQuanjing_db2019 <<EOF
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'QJ_neutron2019';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'QJ_neutron2019';
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
openstack user create --domain default --password=quanjing neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://${ip}:9696
openstack endpoint create --region RegionOne network internal http://${ip}:9696
openstack endpoint create --region RegionOne network admin http://${ip}:9696
#安装Provider网络的软件包和初始化相关组件
yum install -y openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge ebtables
openstack-config --set  /etc/neutron/neutron.conf database connection  mysql+pymysql://neutron:QJ_neutron2019@${ip}/neutron 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT core_plugin  ml2  
openstack-config --set  /etc/neutron/neutron.conf DEFAULT service_plugins 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT transport_url rabbit://openstack:quanjing@${ip}
openstack-config --set  /etc/neutron/neutron.conf DEFAULT auth_strategy  keystone  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken www_authenticate_uri  http://${ip}:5000
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_url  http://${ip}:5000
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken memcached_servers  ${ip}:11211
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_type  password  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_domain_name default  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken user_domain_name  default  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_name  service  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken username  neutron  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken password  quanjing  
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes  True  
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes  True  
openstack-config --set  /etc/neutron/neutron.conf nova auth_url  http://${ip}:5000
openstack-config --set  /etc/neutron/neutron.conf nova auth_type  password 
openstack-config --set  /etc/neutron/neutron.conf nova project_domain_name  default  
openstack-config --set  /etc/neutron/neutron.conf nova user_domain_name  default  
openstack-config --set  /etc/neutron/neutron.conf nova region_name  RegionOne  
openstack-config --set  /etc/neutron/neutron.conf nova project_name  service  
openstack-config --set  /etc/neutron/neutron.conf nova username  nova  
openstack-config --set  /etc/neutron/neutron.conf nova password  quanjing  
openstack-config --set  /etc/neutron/neutron.conf oslo_concurrency lock_path  /var/lib/neutron/tmp  
grep "^[a-z]" /etc/neutron/neutron.conf

openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers  flat,vlan
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers  linuxbridge
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers  port_security
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks  provider 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset  True 
grep "^[a-z]" /etc/neutron/plugins/ml2/ml2_conf.ini

openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings  provider:ens224
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan  enable_vxlan  False
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  enable_security_group  True 
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
grep "^[a-z]" /etc/neutron/plugins/ml2/linuxbridge_agent.ini

openstack-config --set   /etc/neutron/dhcp_agent.ini DEFAULT  interface_driver  linuxbridge
openstack-config --set   /etc/neutron/dhcp_agent.ini DEFAULT  dhcp_driver  neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set   /etc/neutron/dhcp_agent.ini DEFAULT  enable_isolated_metadata  True 
grep "^[a-z]" /etc/neutron/dhcp_agent.ini

openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_host ${ip}
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret quanjing
grep "^[a-z]" /etc/neutron/metadata_agent.ini

openstack-config --set  /etc/nova/nova.conf  neutron url http://${ip}:9696
openstack-config --set  /etc/nova/nova.conf  neutron auth_url http://${ip}:5000
openstack-config --set  /etc/nova/nova.conf  neutron auth_type password
openstack-config --set  /etc/nova/nova.conf  neutron project_domain_name default
openstack-config --set  /etc/nova/nova.conf  neutron user_domain_name default
openstack-config --set  /etc/nova/nova.conf  neutron region_name RegionOne
openstack-config --set  /etc/nova/nova.conf  neutron project_name service
openstack-config --set  /etc/nova/nova.conf  neutron username neutron
openstack-config --set  /etc/nova/nova.conf  neutron password quanjing
openstack-config --set  /etc/nova/nova.conf  neutron service_metadata_proxy true
openstack-config --set  /etc/nova/nova.conf  neutron metadata_proxy_shared_secret quanjing
grep "^[a-z]" /etc/nova/nova.conf

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
#同步数据库
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
#启动服务
systemctl restart openstack-nova-api.service
systemctl enable neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
systemctl start neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
