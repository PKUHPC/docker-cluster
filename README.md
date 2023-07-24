# Slurm Docker Cluster

This is a multi-container Slurm cluster using docker-compose.  The compose file
creates named volumes for persistent storage of MySQL data files as well as
Slurm state and log directories.

## Containers and Volumes

The compose file will run the following containers:

* mysql
* slurmdbd
* slurmctld
* c1 (slurmd)
* c2 (slurmd)

The compose file will create the following named volumes:

* etc_munge         ( -> /etc/munge     )
* etc_slurm         ( -> /etc/slurm     )
* slurm_jobdir      ( -> /data          )
* var_lib_mysql     ( -> /var/lib/mysql )
* var_log_slurm     ( -> /var/log/slurm )

## Building the Docker Image

Build the image locally:

```console
docker build -t slurm-docker-cluster:21.08.6 .
```

Build a different version of Slurm using Docker build args and the Slurm Git
tag:

```console
docker build --build-arg SLURM_TAG="slurm-19-05-2-1" -t slurm-docker-cluster:19.05.2 .
```

Or equivalently using `docker-compose`:

```console
SLURM_TAG=slurm-19-05-2-1 IMAGE_TAG=19.05.2 docker-compose build
```


## Starting the Cluster

Run `docker-compose` to instantiate the cluster:

```console
IMAGE_TAG=19.05.2 docker-compose up -d
```

## Register the Cluster with SlurmDBD

To register the cluster to the slurmdbd daemon, run the `register_cluster.sh`
script:

```console
./register_cluster.sh
```

> Note: You may have to wait a few seconds for the cluster daemons to become
> ready before registering the cluster.  Otherwise, you may get an error such
> as **sacctmgr: error: Problem talking to the database: Connection refused**.
>
> You can check the status of the cluster by viewing the logs: `docker-compose
> logs -f`

## Accessing the Cluster

Use `docker exec` to run a bash shell on the controller container:

```console
docker exec -it slurmctld bash
```

From the shell, execute slurm commands, for example:

```console
[root@slurmctld /]# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal*      up 5-00:00:00      2   idle c[1-2]
```

## Submitting Jobs

The `slurm_jobdir` named volume is mounted on each Slurm container as `/data`.
Therefore, in order to see job output files while on the controller, change to
the `/data` directory when on the **slurmctld** container and then submit a job:

```console
[root@slurmctld /]# cd /data/
[root@slurmctld data]# sbatch --wrap="uptime"
Submitted batch job 2
[root@slurmctld data]# ls
slurm-2.out
```

## Stopping and Restarting the Cluster

```console
docker-compose stop
docker-compose start
```

## Deleting the Cluster

To remove all containers and volumes, run:

```console
docker-compose stop
docker-compose rm -f
docker volume rm slurm-docker-cluster_etc_munge slurm-docker-cluster_etc_slurm slurm-docker-cluster_slurm_jobdir slurm-docker-cluster_var_lib_mysql slurm-docker-cluster_var_log_slurm
```


ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ''

docker network create --subnet=10.100.20.0/24 scow

firewall-cmd --add-rich-rule='rule family="ipv4" forward-port to-addr="172.18.0.6" to-port="5900-6900" protocol="tcp" port="5900-6900"'

docker network create -d macvlan --subnet=192.168.8.0/24 --gateway=192.168.8.2  -o  parent=ens33 slurm-net


docker network create -d macvlan --subnet=172.16.20.0/24 --gateway=172.16.20.254  -o  parent=ens192 slurm-net


# 以下操作都在宿主机上运行，新增一个叫mynet(不要和容器的macvlan重名)的macvlan接口
ip link add mynet link ens33 type macvlan mode bridge
# 为该接口分配ip，并启用
ip addr add 192.168.8.201 dev mynet
ip link set mynet up
# 修改路由，使宿主机到192.168.0.100的通信全部经由mynet进行
ip route add 192.168.8.136 dev mynet