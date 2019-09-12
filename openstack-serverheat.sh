#!/bin/bash
ip=$(ip -4 -f inet addr show ${eth} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/' | grep 168.61)
mysql -u root -pQuanjing_db2019 <<EOF
CREATE DATABASE heat;
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'localhost' IDENTIFIED BY 'QJ_heat2019';
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'%' IDENTIFIED BY 'QJ_heat2019';
flush privileges;
EOF
#创建对应的用户注册heat的服务
export OS_USERNAME=admin
export OS_PASSWORD=quanjing
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://${ip}:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
openstack user create --domain default --password=quanjing heat
openstack role add --project service --user heat admin
openstack service create --name heat --description "Orchestration" orchestration
openstack service create --name heat-cfn --description "Orchestration"  cloudformation
openstack endpoint create --region RegionOne orchestration public http://${ip}:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne orchestration internal http://${ip}:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne orchestration admin http://${ip}:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne cloudformation public http://${ip}:8000/v1
openstack endpoint create --region RegionOne cloudformation internal http://${ip}:8000/v1
openstack endpoint create --region RegionOne cloudformation admin http://${ip}:8000/v1

openstack domain create --description "Stack projects and users" heat
openstack user create --domain heat --password=quanjing heatadmin
openstack role add --domain heat --user-domain heat --user heatadmin admin
openstack role create heat_stack_owner
openstack role add --project service --user qjops heat_stack_owner
openstack role create heat_stack_user
#开始安装服务
yum install -y openstack-heat-api openstack-heat-api-cfn openstack-heat-engine
openstack-config --set  /etc/heat/heat.conf database connection  mysql+pymysql://heat:QJ_heat2019@${ip}/heat
openstack-config --set  /etc/heat/heat.conf DEFAULT transport_url  rabbit://openstack:quanjing@${ip}
openstack-config --set  /etc/heat/heat.conf keystone_authtoken auth_uri  http://${ip}:5000
openstack-config --set  /etc/heat/heat.conf keystone_authtoken auth_url  http://${ip}:35357
openstack-config --set  /etc/heat/heat.conf keystone_authtoken memcached_servers  ${ip}:11211
openstack-config --set  /etc/heat/heat.conf keystone_authtoken auth_type  password
openstack-config --set  /etc/heat/heat.conf keystone_authtoken project_domain_name  default 
openstack-config --set  /etc/heat/heat.conf keystone_authtoken user_domain_name  default
openstack-config --set  /etc/heat/heat.conf keystone_authtoken project_name  service 
openstack-config --set  /etc/heat/heat.conf keystone_authtoken username  heat
openstack-config --set  /etc/heat/heat.conf keystone_authtoken password  quanjing
openstack-config --set  /etc/heat/heat.conf trustee auth_type password
openstack-config --set  /etc/heat/heat.conf trustee auth_url  http://${ip}:35357
openstack-config --set  /etc/heat/heat.conf trustee username  heat
openstack-config --set  /etc/heat/heat.conf trustee password  quanjing
openstack-config --set  /etc/heat/heat.conf trustee user_domain_name  default
openstack-config --set  /etc/heat/heat.conf clients_keystone auth_uri  http://${ip}:5000
openstack-config --set  /etc/heat/heat.conf DEFAULT heat_metadata_server_url  http://${ip}:8000
openstack-config --set  /etc/heat/heat.conf DEFAULT heat_waitcondition_server_url  http://${ip}:8000/v1/waitcondition
openstack-config --set  /etc/heat/heat.conf DEFAULT stack_domain_admin heatadmin
openstack-config --set  /etc/heat/heat.conf DEFAULT stack_domain_admin_password quanjing
openstack-config --set  /etc/heat/heat.conf DEFAULT stack_user_domain_name heat
egrep -v "^#|^$" /etc/heat/heat.conf

su -s /bin/sh -c "heat-manage db_sync" heat
mysql -u root -pQuanjing_db2019 -e "use heat;show tables;"
systemctl enable openstack-heat-api.service openstack-heat-api-cfn.service openstack-heat-engine.service
systemctl start openstack-heat-api.service openstack-heat-api-cfn.service openstack-heat-engine.service
