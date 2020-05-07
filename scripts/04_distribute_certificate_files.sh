#!/bin/bash

echo "-- 04. DISTRIBUTE CERTIFICATES"

# Workers

AWS_WORKER_CLI_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_worker_*_instance"\
 "Name=instance-state-name,Values=running" --profile=default --region=ap-southeast-1)
INSTANCE_IDS=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[].InstanceId') 

for instance in $INSTANCE_IDS; do

PUBLIC_IP=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PublicIpAddress') 
PRIVATE_IP=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PrivateIpAddress') 
PRIVATE_DNS=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PrivateDnsName' | cut -d'.' -f1) 

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa ca.pem $PRIVATE_DNS-key.pem $PRIVATE_DNS.pem ubuntu@$PUBLIC_IP:~/

done

# Controllers

AWS_CONTROLLER_CLI_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance"\
 "Name=instance-state-name,Values=running" --profile=default --region=ap-southeast-1)
INSTANCE_IDS=$(echo $AWS_CONTROLLER_CLI_RESULT | jq -r '.Reservations[].Instances[].InstanceId')

for instance in $INSTANCE_IDS; do

PUBLIC_IP=$(echo $AWS_CONTROLLER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PublicIpAddress') 

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ubuntu@$PUBLIC_IP:~/

done
