#!/bin/bash
ip=$(ip -4 -f inet addr show ${eth} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/' | grep 168.61)
mysql -u root -pQuanjing_db2019 <<EOF
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'QJ_keys2019';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'QJ_keys2019';
flush privileges;
EOF
#这里使用Openstack-utils工具来完成快速配置
yum install -y  openstack-keystone httpd mod_wsgi python-keystoneclient openstack-utils
openstack-config --set /etc/keystone/keystone.conf database connection mysql+pymysql://keystone:QJ_keys2019@${ip}/keystone
openstack-config --set /etc/keystone/keystone.conf token provider fernet
grep "^[a-z]" /etc/keystone/keystone.conf
su -s /bin/sh -c "keystone-manage db_sync" keystone
mysql -u root -pQuanjing_db2019 -e "use keystone;show tables;"
#注意在多节点的keystone环境中在一台机器上执行初始化密钥然后复制/etc/keystone/fernet-keys/ 到其他节点确保加解密的基础密钥一样
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
sed  -i  "s/#ServerName www.example.com:80/ServerName ${ip}/" /etc/httpd/conf/httpd.conf
cp /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
systemctl enable httpd.service
systemctl start httpd.service
netstat -anptl|grep httpd
#在公共、内部和管理区域创建身份验证服务，密码quanjing
keystone-manage bootstrap --bootstrap-password quanjing \
  --bootstrap-admin-url http://${ip}:5000/v3/ \
  --bootstrap-internal-url http://${ip}:5000/v3/ \
  --bootstrap-public-url http://${ip}:5000/v3/ \
  --bootstrap-region-id RegionOne
#定义环境变量，OS_PASSWORD为上述设置的密码
ip=$(ip -4 -f inet addr show ${eth} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/' | grep 168.61)
export OS_USERNAME=admin
export OS_PASSWORD=quanjing
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://${ip}:5000/v3
export OS_IDENTITY_API_VERSION=3
#查看设置的环境变量是否正确
env |grep OS_
