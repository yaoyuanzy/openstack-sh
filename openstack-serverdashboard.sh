#!/bin/bash
yum install -y openstack-dashboard
egrep -v  "^#|^$" /etc/openstack-dashboard/local_settings > /etc/openstack-dashboard/local_settings.new
mv /etc/openstack-dashboard/local_settings /etc/openstack-dashboard/local_settings.bak
mv /etc/openstack-dashboard/local_settings.new /etc/openstack-dashboard/local_settings
cd /etc/openstack-dashboard/
sed -i 's/^OPENSTACK_HOST.*/OPENSTACK_HOST = "192.168.61.230"/g' local_settings
sed -i "s/^ALLOWED_HOSTS.*/ALLOWED_HOSTS = [\'*\', ]/g" local_settings
sed -i 's/^OPENSTACK_KEYSTONE_DEFAULT_ROLE.*/OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"/g' local_settings
sed -i 's/^TIME_ZONE.*/TIME_ZONE = "Asia\/Shanghai"/g' local_settings


cat <<EOF >>/etc/openstack-dashboard/local_settings
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
CACHES = {
    'default': {
         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
         'LOCATION': '192.168.61.230:11211',
    }
}
OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 2,
}
OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True
OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "default"
EOF
echo "WSGIApplicationGroup %{GLOBAL}" >> /etc/httpd/conf.d/openstack-dashboard.conf
echo -e "Still need to change /etc/openstack-dashboard/local_settings with manual,look at /root/tishi\n"
cat <<EOF >/root/tishi
#定位到文件 /etc/openstack-dashboard/local_settings 这块手动修改，因网路不同而做不同改动
#OPENSTACK_NEUTRON_NETWORK = {
    'enable_router': False,
    'enable_quotas': False,
    'enable_ipv6': False,
    'enable_distributed_router': False,
    'enable_ha_router': False,
    'enable_fip_topology_check': False,
    'enable_lb': False,
    'enable_firewall': False,
    'enable_vpn': False,
#}
#systemctl restart httpd.service memcached.service
echo -e "Visit http://192.168.61.230/dashboard with default domain admin quanjing/n"
EOF
