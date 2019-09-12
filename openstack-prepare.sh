#!/bin/bash
echo 'bonding' >> /etc/modules-load.d/openstack-ansible.conf
echo '8021q' >> /etc/modules-load.d/openstack-ansible.conf
echo "1 quanjing" >/etc/chrony.keys
sed -i "s/server/#server/g" /etc/chrony.conf
echo "server 192.168.62.13 iburst" >>/etc/chrony.conf
systemctl enable chronyd.service
systemctl restart chronyd.service
rpm -ivh http://192.168.61.210/dl/rpm/rdo-release.rpm
yum install -y centos-release-openstack-rocky
#Install the OpenStack client，selinux is not use
yum install -y python-openstackclient openstack-selinux
