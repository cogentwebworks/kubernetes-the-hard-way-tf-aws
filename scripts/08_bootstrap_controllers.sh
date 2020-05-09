#!/bin/bash

echo "-- 08. BOOTSTRAP CONTROLLERS"

# Create inventory file just in case
DIRECTORY=$(dirname $0)
$DIRECTORY/00_create_ansible_inventory.sh

ansible-playbook -vvv -i kube_full_inventory.yml ../ansible/08_bootstrap_controllers.yml  --private-key=~/.ssh/id_rsa

KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers --names "kube-loadbalancer"\
 --output text --query 'LoadBalancers[].DNSName' --profile=default --region=ap-southeast-1)

curl -k --cacert ca.pem https://"${KUBERNETES_PUBLIC_ADDRESS}"/version
