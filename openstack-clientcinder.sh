#!/bin/bash
ip=$(ip -4 -f inet addr show ${eth} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/' | grep 168.61)
yum install -y lvm2 device-mapper-persistent-data 
systemctl enable lvm2-lvmetad.service
systemctl start lvm2-lvmetad.service
dd if=/dev/zero of=/dev/sdb bs=512k count=2
pvcreate /dev/sdb
vgcreate cinder-volumes /dev/sdb
142行前面插入filter避免被lvm扫描
a=`echo 'filter = [ "a|/dev/sdb|", "r|.*/|" ]'` | sed -i "142i ${a}" /etc/lvm/lvm.conf
yum install -y openstack-cinder targetcli python-keystone
openstack-config --set  /etc/cinder/cinder.conf database connection  mysql+pymysql://cinder:QJ_cinder2019@192.168.61.230/cinder
openstack-config --set  /etc/cinder/cinder.conf DEFAULT transport_url  rabbit://openstack:quanjing@192.168.61.230
openstack-config --set  /etc/cinder/cinder.conf DEFAULT auth_strategy  keystone 
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken www_authenticate_uri  http://192.168.61.230:5000
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken auth_url  http://192.168.61.230:5000
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken memcached_servers  192.168.61.230:11211
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken auth_type  password
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken project_domain_name  default 
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken user_domain_name  default
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken project_name  service 
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken username  cinder
openstack-config --set  /etc/cinder/cinder.conf keystone_authtoken password  quanjing
openstack-config --set  /etc/cinder/cinder.conf DEFAULT my_ip ${ip}
openstack-config --set  /etc/cinder/cinder.conf lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
openstack-config --set  /etc/cinder/cinder.conf lvm volume_group cinder-volumes
openstack-config --set  /etc/cinder/cinder.conf lvm iscsi_protocol  iscsi
openstack-config --set  /etc/cinder/cinder.conf lvm iscsi_helper  lioadm
openstack-config --set  /etc/cinder/cinder.conf DEFAULT enabled_backends  lvm
openstack-config --set  /etc/cinder/cinder.conf DEFAULT glance_api_servers  http://192.168.61.230:9292
openstack-config --set  /etc/cinder/cinder.conf oslo_concurrency lock_path  /var/lib/cinder/tmp
egrep -v "^#|^$" /etc/cinder/cinder.conf
systemctl enable openstack-cinder-volume.service target.service
systemctl start openstack-cinder-volume.service target.service
