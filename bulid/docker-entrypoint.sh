#!/bin/bash
set -e

if [ "$1" = "slurmdbd" ]
then
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    gosu munge /usr/sbin/munged

    echo "---> Starting the Slurm Database Daemon (slurmdbd) ..."

    {
        . /etc/slurm/slurmdbd.conf
        until echo "SELECT 1" | mysql -h $StorageHost -u$StorageUser -p$StoragePass 2>&1 > /dev/null
        do
            echo "-- Waiting for database to become active ..."
            sleep 2
        done
    }
    echo "-- Database is now active ..."
    #systemctl restart sssd
   # systemctl start systemd-logind
   # systemctl start oddjobd
    supervisord -c /etc/supervisor/conf.d/slurmdbd_supervisord.conf
    #exec gosu slurm /usr/sbin/slurmdbd -Dvvv
fi

if [ "$1" = "slurmctld" ]
then
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    #supervisord -c /etc/supervisor/conf.d/supervisord.conf
    #nohup /adapter/scow-slurm-adapter-amd64 > /adapter/server.log 2>&1 &
    gosu munge /usr/sbin/munged
    
    #systemctl restart sssd
    #systemctl start systemd-logind
    #systemctl start oddjobd
    echo "---> Waiting for slurmdbd to become active before starting slurmctld ..."

    until 2>/dev/null >/dev/tcp/slurmdbd/6819
    do
        echo "-- slurmdbd is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmdbd is now active ..."

    echo "---> Starting the Slurm Controller Daemon (slurmctld) ..."
    if /usr/sbin/slurmctld -V | grep -q '17.02' ; then
        exec gosu slurm /usr/sbin/slurmctld -Dvvv
    else
        #exec gosu slurm /usr/sbin/slurmctld -i -Dvvv
        supervisord -c /etc/supervisor/conf.d/slurmctld_supervisord.conf
    fi
fi

if [ "$1" = "slurmd" ]
then
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    #supervisord -c /etc/supervisor/conf.d/supervisord.conf
    gosu munge /usr/sbin/munged
    #systemctl restart sssd
    #systemctl start systemd-logind
    #systemctl start oddjobd    

    echo "---> Waiting for slurmctld to become active before starting slurmd..."

    until 2>/dev/null >/dev/tcp/slurmctld/6817
    do
        echo "-- slurmctld is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmctld is now active ..."

    echo "---> Starting the Slurm Node Daemon (slurmd) ..."
   # exec /usr/sbin/slurmd -Dvvv
    supervisord -c /etc/supervisor/conf.d/slurmd_supervisord.conf
fi

exec "$@"
