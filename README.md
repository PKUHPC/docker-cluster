## 1. 环境要求

- docker
- docker-compose
- firewall
- 其他

环境配置参见[基础环境准备](doc/base.md)



## 2. 使用

### 2.1 启动slurm集群

克隆代码

```shell
git clone https://github.com/PKUHPC/docker-cluster.git
```

启动slurm集群

```shell
# 进入项目目录
cd docker-cluster

# 拉取镜像
docker-compose pull

# 启动
docker-compose up -d

# 删除
docker-compose down
```

所有容器使用slurm-net网络，slurm启动后有如下服务：

| 服务名称  |    IP地址     |         备注         |
| :-------: | :-----------: | :------------------: |
|   mysql   | 10.100.20.131 |                      |
|   ldap    | 10.100.20.132 | 389端口映射到宿主机  |
| slurmdbd  | 10.100.20.133 |                      |
| slurmctld | 10.100.20.134 | 8999端口(适配器)映射到宿主机 |
|    c1     | 10.100.20.135 |                      |
|   login   | 10.100.20.136 |                      |

> ldap管理员用户: cn=Manager,ou=hpc,o=pku，密码:admin

### 2.2 启动SCOW

```shell
# 进入目录
cd docker-cluster/scow-cli

# 下载cli，此次下载v0.8.1，可按需调整
wget https://github.com/PKUHPC/SCOW/releases/download/v0.8.1/cli-x64
mv cli-x64 cli
chmod +x cli

# 启动SCOW
./cli compose up -d
```

为保证与slurm登录容器节点、计算容器节点的网络连通性，所有SCOW容器使用slurm-net网络，其中redis服务的默认IP地址为：`10.100.20.140`(转发配置需要)，此部分设置通过cli的插件实现。

> SCOW的其他部署等操作请参见[相关文档](https://pkuhpc.github.io/SCOW/docs/deploy)

### 2.3 slurm多登录节点支持

修改`docker-compose.yml`文件，参照login节点部分的内容，添加一个login02:

```yaml
  login02:
    image: mirrors.pku.edu.cn/pkuhpc-icode/slurm-docker/slurm:${IMAGE_TAG:-login-21.08.6}
    command: ["slurmd"]
    privileged: true
    hostname: login02
    container_name: login02
    volumes:
      - etc_munge:/etc/munge
      - etc_slurm:/etc/slurm
      - slurm_jobdir:/data
      - var_log_slurm:/var/log/slurm
      - /root/.ssh/authorized_keys:/root/.ssh/authorized_keys
    expose:
      - "6818"
    depends_on:
      - "slurmctld"
    networks:
      slurm-net:
        ipv4_address: 10.100.20.137
```

修改slurm配置：

```shell
# 进入slurm配置文件目录,路径中的 docker-cluster_etc_slurm 根据本机环境相应变化
cd /var/lib/docker/volumes/docker-cluster_etc_slurm/_data

# 在slurm.conf的# COMPUTE NODES部分添加login02节点
NodeName=login02 RealMemory=1000 State=UNKNOWN
```

重启slurm集群：

```shell
docker-compose down
docker-compsoe up -d
```

配置login02容器节点的ssh转发端口，例如本机3022端口：

```shell
firewall-cmd --permanent --add-forward-port=port=3022:proto=tcp:toaddr=10.100.20.137:toport=22
firewall-cmd --reload
```

SCOW登录节点配置修改：

```yaml
vim config/clusters/linux.yaml

# 添加登录节点02配置,loginNodes部分添加如下配置

  - name: 登录节点02
    # 登录节点的IP或者域名
    # 如果设置的是域名，请确认此节点的/etc/hosts中包含了域名到IP的解析信息
    address: 10.100.20.137
    
# 重启SCOW
./cli compose down
./cli compose up -d
```

