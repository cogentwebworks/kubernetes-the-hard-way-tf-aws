#!/bin/bash

echo "-- 10. CONFIGURE KUBECTL"

KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers --names "kube-loadbalancer"\
 --output text --query 'LoadBalancers[].DNSName' --profile=sysops --region=ap-southeast-1)

kubectl config set-cluster kubics\
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:443

kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem

kubectl config set-context kubics\
  --cluster=kubics\
  --user=admin

kubectl config use-context kubics

kubectl get componentstatus

kubectl get nodes
