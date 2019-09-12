#!/bin/bash
ip=$(ip -4 -f inet addr show ${eth} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/' | grep 168.61)
export OS_USERNAME=admin
export OS_PASSWORD=quanjing
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://${ip}:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
yum install -y openstack-nova-compute python-openstackclient openstack-utils 
openstack-config --set  /etc/nova/nova.conf DEFAULT my_ip ${ip}
openstack-config --set  /etc/nova/nova.conf DEFAULT use_neutron True
openstack-config --set  /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set  /etc/nova/nova.conf DEFAULT enabled_apis  osapi_compute,metadata
openstack-config --set  /etc/nova/nova.conf DEFAULT transport_url  rabbit://openstack:quanjing@192.168.61.230
openstack-config --set  /etc/nova/nova.conf api auth_strategy  keystone 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_url http://192.168.61.230:5000/v3
openstack-config --set  /etc/nova/nova.conf keystone_authtoken memcached_servers 192.168.61.230:11211
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_type password
openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_domain_name default
openstack-config --set  /etc/nova/nova.conf keystone_authtoken user_domain_name default
openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_name  service
openstack-config --set  /etc/nova/nova.conf keystone_authtoken username nova
openstack-config --set  /etc/nova/nova.conf keystone_authtoken password quanjing
openstack-config --set  /etc/nova/nova.conf vnc enabled True
openstack-config --set  /etc/nova/nova.conf vnc server_listen 0.0.0.0
openstack-config --set  /etc/nova/nova.conf vnc server_proxyclient_address  '$my_ip'
openstack-config --set  /etc/nova/nova.conf vnc novncproxy_base_url  http://192.168.61.230:6080/vnc_auto.html
openstack-config --set  /etc/nova/nova.conf glance api_servers http://192.168.61.230:9292
openstack-config --set  /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp
openstack-config --set  /etc/nova/nova.conf placement region_name RegionOne
openstack-config --set  /etc/nova/nova.conf placement project_domain_name Default
openstack-config --set  /etc/nova/nova.conf placement project_name service
openstack-config --set  /etc/nova/nova.conf placement auth_type password
openstack-config --set  /etc/nova/nova.conf placement user_domain_name Default
openstack-config --set  /etc/nova/nova.conf placement auth_url http://192.168.61.230:5000/v3
openstack-config --set  /etc/nova/nova.conf placement username placement
openstack-config --set  /etc/nova/nova.conf placement password quanjing
#检查配置是否正确,查看机器是否支持虚拟机硬件加速来设置不同的管理虚拟机方式
grep '^[a-z]' /etc/nova/nova.conf
type=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ $type == 0 ];then
openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu
else
openstack-config --set  /etc/nova/nova.conf libvirt virt_type  kvm
fi    
#启动服务
systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service openstack-nova-compute.service
#将计算节点手动加入cell数据库，默认的自动发现间隔时间在配置文件中设置的300s
#su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
