## 1. 环境要求

- docker
- docker-compose
- firewalld
- 其他

环境配置参见：[基础环境准备](doc/base.md)



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

# 向SlurmDBD注册集群
./register_cluster.sh
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

进入slurmctld容器，进行集群管理

```shell
# 进入slurmctld容器
docker exec -it slurmctld bash

# 查看集群信息
sinfo

# 进入共享目录
cd /data/

# 创建用户家目录、软件安装目录
mkdir home software
```



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

### 2.4 多集群支持

修改`docker-compose.yaml`，增加slurm_02集群的容器，`services`节点下增加如下配置：

```yaml
 mysql_02:
    image: mirrors.pku.edu.cn/pkuhpc-icode/slurm-docker/mariadb:10.10
    hostname: mysql_02
    container_name: mysql_02
    environment:
      MYSQL_RANDOM_ROOT_PASSWORD: "yes"
      MYSQL_DATABASE: slurm_acct_db
      MYSQL_USER: slurm
      MYSQL_PASSWORD: password
    volumes:
      - var_lib_mysql_02:/var/lib/mysql
    networks:
      slurm-net:
        ipv4_address: 10.100.20.231


  slurmdbd_02:
    image: mirrors.pku.edu.cn/pkuhpc-icode/slurm-docker/slurm:${IMAGE_TAG:-compute-21.08.6}
    build:
      context: .
      args:
        SLURM_TAG: ${SLURM_TAG:-slurm-21-08-6-1}
    command: ["slurmdbd"]
    container_name: slurmdbd_02
    hostname: slurmdbd_02
    privileged: true
    volumes:
      - etc_munge_02:/etc/munge
      - etc_slurm_02:/etc/slurm
      - var_log_slurm_02:/var/log/slurm
    expose:
      - "6819"
    depends_on:
      - mysql_02
      - ldap
    networks:
      slurm-net:
        ipv4_address: 10.100.20.233

  slurmctld_02:
    image: mirrors.pku.edu.cn/pkuhpc-icode/slurm-docker/slurm:${IMAGE_TAG:-compute-21.08.6}
    command: ["slurmctld"]
    container_name: slurmctld_02
    hostname: slurmctld_02
    privileged: true
    volumes:
      - etc_munge_02:/etc/munge
      - etc_slurm_02:/etc/slurm
      - slurm_jobdir_02:/data
      - var_log_slurm_02:/var/log/slurm
    expose:
      - "6817"
      - "8999"
    ports:
      - '8998:8999'
    depends_on:
      - "slurmdbd_02"
    networks:
      slurm-net:
        ipv4_address: 10.100.20.234

  c1_02:
    image: mirrors.pku.edu.cn/pkuhpc-icode/slurm-docker/slurm:${IMAGE_TAG:-compute-21.08.6}
    command: ["slurmd"]
    hostname: c1_02
    privileged: true
    container_name: c1_02
    volumes:
      - etc_munge_02:/etc/munge
      - etc_slurm_02:/etc/slurm
      - slurm_jobdir_02:/data
      - var_log_slurm_02:/var/log/slurm
    expose:
      - "6818"
    depends_on:
      - "slurmctld_02"
    networks:
      slurm-net:
        ipv4_address: 10.100.20.235

  login_02:
    image: mirrors.pku.edu.cn/pkuhpc-icode/slurm-docker/slurm:${IMAGE_TAG:-login-21.08.6}
    command: ["slurmd"]
    privileged: true
    hostname: login_02
    container_name: login_02
    volumes:
      - etc_munge_02:/etc/munge
      - etc_slurm_02:/etc/slurm
      - slurm_jobdir_02:/data
      - var_log_slurm_02:/var/log/slurm
      - /root/.ssh/authorized_keys:/root/.ssh/authorized_keys
    expose:
      - "6818"
    depends_on:
      - "slurmctld_02"
    networks:
      slurm-net:
        ipv4_address: 10.100.20.236
```

volumes节点下增加如下配置：

```yaml
  etc_munge_02:
  etc_slurm_02:
  slurm_jobdir_02:
  var_lib_mysql_02:
  var_log_slurm_02:
```

> 主要修改的配置是容器名称、IP，volumes名称及映射，端口映射，确保与第一个集群隔离的同时使用相同的LDAP。详细配置参见：[docker-compose.multi-cluster.yml](docker-compose.multi-cluster.yml)



修改slurm配置文件`slurm.conf`，主要修改hostname相关配置，改为slurm_02集群配置：

```shell
# 路径中docker-cluster_etc_slurm_02根据实际环境可能有所不同，注意调整
vim  /var/lib/docker/volumes/docker-cluster_etc_slurm_02/_data/slurm.conf

# 修改如下参数：
ClusterName=slurm_02
ControlMachine=slurmctld_02
ControlAddr=slurmctld_02

AccountingStorageHost=slurmdbd_02

NodeName=c1_02 RealMemory=1000 State=UNKNOWN
NodeName=login_02 RealMemory=1000 State=UNKNOWN

PartitionName=normal Default=yes Nodes=c1_02 Priority=50 DefMemPerCPU=500 Shared=NO MaxNodes=2 MaxTime=5-00:00:00 DefaultTime=5-00:00:00 State=UP
```

修改slurmdbd.conf：

```shell
# 路径中docker-cluster_etc_slurm_02根据实际环境可能有所不同，注意调整
vim  /var/lib/docker/volumes/docker-cluster_etc_slurm_02/_data/slurmdbd.conf

# 修改如下参数：
DbdAddr=slurmdbd_02
DbdHost=slurmdbd_02
StorageHost=mysql_02
```

重启集群：

```shell
docker-compose down
docker-compose up -d
```

> slurm_02集群firewall端口开放、端口转发参见前述文档。slurmdbd_02集群接入SCOW参见多集群接入

## 3. 其他

- [镜像构建](doc/images.md)

- slurm集群搭建参考：[slurm-docker-cluster](https://github.com/giovtorres/slurm-docker-cluster)

  