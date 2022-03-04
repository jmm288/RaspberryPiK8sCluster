#!/usr/bin/env bash
RPI_MASTERIP="$1"
RPI_MASTERPORT="25000"
RPI_LEAVES="$@"
RPI_MASTER_SSH_USER="pi"
RPI_LEAF_SSH_USER="pi"
RPI_DEFAULT_GATEWAY="192.168.1.1"
RPI_SUBNET_MASK="255.255.255.0"

usage="$(basename "$0") <MASTER_IP_ADDRESS> <LEAF_IP_ADDRESS> <LEAF_IP_ADDRESS> <ETC> -- Script to create and join and microk8s with raspberry pi.

where:
    -h show this help text"

while getopts ':h:' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    :) echo "missing argument"
       echo "$usage" >&2
       exit 1
       ;;
   \?) echo "illegal option"
       echo "$usage" >&2
       exit 1
       ;;
  esac
done

# Create and Join Cluster
for leaf; do
  if [ "$leaf" = $RPI_MASTERIP ] ; then
    echo "master leaf: $leaf"
    # Enable C-group on MASTER and LEAF node(s). Remove a newline at the end of the cmdline file.
    ssh $RPI_MASTER_SSH_USER@$RPI_MASTERIP "sudo truncate -s -1 /boot/cmdline.txt && sudo sed -i \"s/$/ cgroup_memory=1 cgroup_enable=memory ip=$RPI_MASTERIP::$RPI_DEFAULT_GATEWAY:$RPI_SUBNET_MASK:rpi1:eth0:off/\" /boot/cmdline.txt && sudo apt update && sudo apt install snapd && echo 'packages updated and snap installed...' && sudo shutdown --reboot 1 && echo 'C-Groups Enabled, IP Address added, Snap installed. Waiting 2 minutes to continue...'"
    # Wait 1 minute for reboot and 1 minute for server(s) to come back up.
    sleep 120
    # Ssh back into master node, install microk8s, add user permissions to access microk8s, add master node, grep on output to get 1st join command.
    MICROK8_JOIN_COMMAND=$(ssh $RPI_MASTER_SSH_USER@$RPI_MASTERIP "sudo snap install microk8s --classic > /dev/null && sleep 60 && sudo usermod -a -G microk8s $RPI_MASTER_SSH_USER && /snap/bin/microk8s.add-node | grep $RPI_MASTERIP -m 1")
    echo "Join command: $MICROK8_JOIN_COMMAND"
  else
    echo "workers: $leaf"
    # Enable C-groups on LEAF node(s)
    ssh $RPI_LEAF_SSH_USER@$leaf "sudo truncate -s -1 /boot/cmdline.txt && sudo sed -i \"s/$/ cgroup_memory=1 cgroup_enable=memory ip=$leaf::$RPI_DEFAULT_GATEWAY:$RPI_SUBNET_MASK:rpi1:eth0:off/\" /boot/cmdline.txt && sudo apt update && sudo apt install snapd && echo 'packages updated and snap installed...' && sudo shutdown --reboot 1 && echo 'C-Groups Enabled, IP Address added, Snap installed. Waiting 2 minutes to continue...'"
    # Wait 1 minute for reboot and 1 minute for server(s) to come back up.
    sleep 120
    # Ssh into leaf node(s), install microk8s, install snap, add user permissions to access microk8s, add leaf node to cluster.
    ssh $RPI_LEAF_SSH_USER@$leaf "sudo snap install microk8s --classic && sleep 60 && sudo usermod -a -G microk8s $RPI_LEAF_SSH_USER && /snap/bin/$MICROK8_JOIN_COMMAND"
  fi
done


