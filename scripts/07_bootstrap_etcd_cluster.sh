#!/bin/bash

echo "-- 07. BOOTSTRAP ETCD CLUSTER"

# Create inventory file just in case
DIRECTORY=$(dirname $0)
$DIRECTORY/00_create_ansible_inventory.sh

ansible-playbook -vvv -i kube_full_inventory.yml ../ansible/07_bootstrap_etcd_cluster.yml  --private-key=~/.ssh/id_rsa