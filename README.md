#测试openstack时候写的脚本，最好是配合实验的笔记进行。本次rdo安装的rocky版本、centos7的虚拟机环境
1.网卡2张起，一个管理网段61.0/24，一个虚拟机业务网段60.0/24 为了新手好理解全部是access的单网卡。flat最简单的网络模式，可以理解为所有虚拟机通过网桥接到交换机的access网口上位于同一VLAN内。
2.虚拟机最少测试需要1台控制节点，1台计算+网络+存储节点。所谓的超融合也就是除了控制机器之外所有的机器运行计算（虚拟化）+存储（分布式）+网络（VXLAN），实现资源的最大化利用。
3.最少安装的服务有keystone、glance、nova、neutron，这些装完后实际上就能从命令行创建虚拟机了，加上horizon就有可视化的界面但是不怎么好用，扩展还需要cinder、heat等服务。
4.脚本列表如下，执行顺序分别为
在全部机器上执行openstack-prepare.sh；
接着在控制机执行openstack-serverenv.sh，openstack-serverkeystone.sh（keystone*的脚本是在此步骤生成的快速调用环境变量的）；         身份验证服务
然后执行openstack-serverglance.sh完成镜像服务配置；                                                                                镜像服务
然后是openstack-servercompute.sh和openstack-clientcompute.sh分别对Nova的控制和子节点进行初始化；                                   计算服务
接着openstack-servernetwork.sh和openstack-clientnetwork.sh分别对Neutron的控制和子节点进行初始化，这步完成即可创建虚拟机开始测试；  网络服务
然后是在控制节点上执行openstack-serverdashboard.sh开始支持GUI管理集群；                                                            WEB管理服务
然后是openstack-servercinder.sh和openstack-clientcinder.sh分别对Cinder的控制和子节点进行初始化，这步完成可以提供类似云盘存储；     块存储服务
最后是在控制节点上执行openstack-serverheat.sh支持对集群资源的编排                                                                  编排服务  
-rw-r--r-- 1 root root  360 Sep 10 15:37 keystone_admin.sh
-rw-r--r-- 1 root root  362 Sep 10 15:37 keystone_qjops.sh
-rw-r--r-- 1 root root 2558 Sep 12 11:13 openstack-clientcinder.sh
-rw-r--r-- 1 root root 3476 Sep 11 09:53 openstack-clientcompute.sh
-rw-r--r-- 1 root root 2877 Sep 11 14:07 openstack-clientnetwork.sh
-rw-r--r-- 1 root root  541 Sep 11 09:52 openstack-prepare.sh
-rw-r--r-- 1 root root 3403 Sep 12 11:30 openstack-servercinder.sh
-rw-r--r-- 1 root root 6881 Sep 10 21:48 openstack-servercompute.sh
-rw-r--r-- 1 root root 1894 Sep 11 21:19 openstack-serverdashboard.sh
-rw-r--r-- 1 root root 3928 Sep 10 13:27 openstack-serverenv.sh
-rw-r--r-- 1 root root 4424 Sep 10 17:42 openstack-serverglance.sh
-rw-r--r-- 1 root root 4238 Sep 12 14:47 openstack-serverheat.sh
-rw-r--r-- 1 root root 2198 Sep 10 14:46 openstack-serverkeystone.sh
-rw-r--r-- 1 root root 6799 Sep 11 11:36 openstack-servernetwork.sh
