## 构建镜像

使用到的镜像：

| 镜像          | 服务使用                      | 备注                        |
| ------------- | ----------------------------- | --------------------------- |
| mariadb       | slurm数据库                   | 使用官方镜像：mariadb:10.10 |
| ldap          | ldap 服务端                   | 构建镜像                    |
| slurm-compute | slurmdbd、slurmctld、计算节点 | 构建镜像                    |
| slurm-login   | 登录节点                      | 构建镜像                    |

### 1. 构建ldap镜像

```shell
#拉取代码
git clone https://github.com/PKUHPC/docker-cluster.git
cd docker-cluster

#构建镜像，-t 镜像标签可自定义
docker build -f bulid/Dockerfile.ldap -t ldap:sh .
```

### 2. 构建slurm-login镜像

```shell
# 默认构建 slurm-21-08-6-1版本镜像
docker build -f bulid/Dockerfile.login -t slurm-login:21.08.6 .

# 自定义版本：SLURM_TAG
docker build -f bulid/Dockerfile.login --build-arg SLURM_TAG="slurm-22-05-3-1" -t slurm-login:22.05.3 .
```

### 3. 构建slurm-compute镜像

由于登录节点需要安装桌面，会导致镜像较大，因此将登录节点和计算节点镜像区分开。

```shell
# 默认构建 slurm-21-08-6-1版本镜像
docker build -f bulid/Dockerfile.compute -t slurm-compute:21.08.6 .

# 自定义版本：SLURM_TAG
docker build -f bulid/Dockerfile.compute --build-arg SLURM_TAG="slurm-22-05-3-1" -t slurm-compute:22.05.3 .
```

### 4. mariadb镜像

使用官方mariadb镜像：mariadb:10.10。

