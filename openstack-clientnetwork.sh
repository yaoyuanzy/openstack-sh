#!/bin/bash
ip=$(ip -4 -f inet addr show ${eth} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/' | grep 168.61)
#安装Provider网络的软件包和初始化相关组件
yum install -y openstack-neutron-linuxbridge ebtables ipset 
openstack-config --set /etc/neutron/neutron.conf DEFAULT transport_url  rabbit://openstack:quanjing@192.168.61.230
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken www_authenticate_uri  http://192.168.61.230:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://192.168.61.230:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers 192.168.61.230:11211
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_type password
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken username neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken password quanjing
openstack-config --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp
grep "^[a-z]" /etc/neutron/neutron.conf

openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings  provider:ens224
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan  enable_vxlan  False
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  enable_security_group  True 
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
grep "^[a-z]" /etc/neutron/plugins/ml2/linuxbridge_agent.ini

openstack-config --set /etc/nova/nova.conf neutron url http://192.168.61.230:9696
openstack-config --set /etc/nova/nova.conf neutron auth_url http://192.168.61.230:5000
openstack-config --set /etc/nova/nova.conf neutron auth_type password
openstack-config --set /etc/nova/nova.conf neutron project_domain_name default
openstack-config --set /etc/nova/nova.conf neutron user_domain_name default
openstack-config --set /etc/nova/nova.conf neutron region_name RegionOne
openstack-config --set /etc/nova/nova.conf neutron project_name service 
openstack-config --set /etc/nova/nova.conf neutron username neutron
openstack-config --set /etc/nova/nova.conf neutron password quanjing
grep "^[a-z]" /etc/nova/nova.conf

#启动服务
systemctl restart openstack-nova-compute.service
systemctl enable neutron-linuxbridge-agent.service
systemctl start neutron-linuxbridge-agent.service
