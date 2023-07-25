## 基础环境准备

> 以下操基于CentOS7.9

关闭selinux

```shell
setenforce 0
sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/sysconfig/selinux
sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config
reboot
```

时间同步：

```shell
rpm -ivh http://mirrors.wlnmp.com/centos/wlnmp-release-centos.noarch.rpm
yum install ntpdate -y

# 时间同步配置如下：
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' >/etc/timezone
ntpdate ntp.aliyun.com

# 加入到crontab
crontab -e
*/5 * * * * /usr/sbin/ntpdate ntp.aliyun.com
```

生成公私钥和本节点免密：

```shell
# 生成公私钥
ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ''

# 节点免密
cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys 
```

安装docker：

```shell
yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
  
# 设置稳定存储库
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
    
# 安装Docker CE
yum install docker-ce -y

# 安装指定版本Docker CE
yum list docker-ce --showduplicates | sort -r
yum install docker-ce-23.0.6 -y

# 启动Docker CE并设置开机启动
systemctl start docker
systemctl enable docker

# 验证Docker环境
docker run hello-world
```

安装docker-compose：

```Bash
# 下载安装
curl -L "https://github.com/docker/compose/releases/download/v2.7.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
mv docker-compose-linux-x86_64 /usr/local/bin/docker-compose
# 赋权
chmod +x /usr/local/bin/docker-compose

# 验证安装成功
docker-compose --version
```

创建docker slurm容器网络：

```shell
docker network create --subnet=10.100.20.0/24 slurm-net
```

防火墙配置：

```shell
# 确保防火墙开启
systemctl status firewalld

# 以下操作若为多集群，需要为每个集群做一组类似的操作

# 放开SCOW web、db、redis、适配器、ldap端口，若需要将其他端口映射出来也需要通过防火墙放开
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=3306/tcp --permanent
firewall-cmd --zone=public --add-port=6379/tcp --permanent 
firewall-cmd --zone=public --add-port=8999/tcp --permanent
firewall-cmd --zone=public --add-port=389/tcp --permanent

# redis端口转发配置，其中10.100.20.140为scow redis容器的IP
firewall-cmd  --permanent --add-forward-port=port=6379:proto=tcp:toaddr=10.100.20.140:toport=6379

# ssh端口转发配置10.100.20.136为slurm登录容器节点IP，2022为本机端口
firewall-cmd --permanent --add-forward-port=port=2022:proto=tcp:toaddr=10.100.20.136:toport=22

#转发桌面服务端口
firewall-cmd --add-rich-rule='rule family="ipv4" forward-port to-addr="10.100.20.136" to-port="5900-6900" protocol="tcp" port="5900-6900"'  --permanent

firewall-cmd --reload
```

