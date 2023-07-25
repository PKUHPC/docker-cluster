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
| slurmctld | 10.100.20.134 | 8999端口映射到宿主机 |
|    c1     | 10.100.20.135 |                      |
|   login   | 10.100.20.136 |                      |

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





