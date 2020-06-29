#!/bin/bash

echo "-- 04. GENERATE CLIENT CERTIFICATES"

# Certificate Authority

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "TH",
      "L": "Bangkok",
      "O": "Kubernetes",
      "OU": "BK",
      "ST": "Bangkok"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# Admin

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "TH",
      "L": "Bangkok",
      "O": "system:masters",
      "OU": "Kubics",
      "ST": "Bangkok"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

# Worker Certificates

AWS_CLI_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube-worker-*-node" "Name=instance-state-name,Values=running" --profile=sysops --region=ap-southeast-1)
INSTANCE_IDS=$(echo $AWS_CLI_RESULT | jq -r '.Reservations[].Instances[].InstanceId') 

for instance in $INSTANCE_IDS; do

PUBLIC_IP=$(echo $AWS_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PublicIpAddress') 
PUBLIC_DNS=$(echo $AWS_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PublicDnsName') 
PRIVATE_IP=$(echo $AWS_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PrivateIpAddress') 
PRIVATE_DNS=$(echo $AWS_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PrivateDnsName' | cut -d'.' -f1) 

cat > ${PRIVATE_DNS}-csr.json <<EOF
{
  "CN": "system:node:${PRIVATE_DNS}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "TH",
      "L": "Bangkok",
      "O": "system:nodes",
      "OU": "Kubics",
      "ST": "Bangkok"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${PUBLIC_DNS},${PUBLIC_IP},${PRIVATE_IP},${PRIVATE_DNS} \
  -profile=kubernetes \
  ${PRIVATE_DNS}-csr.json | cfssljson -bare ${PRIVATE_DNS}

done

# Controller

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "TH",
      "L": "Bangkok",
      "O": "system:kube-controller-manager",
      "OU": "Kubics",
      "ST": "Bangkok"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

# Proxy

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "TH",
      "L": "Bangkok",
      "O": "system:node-proxier",
      "OU": "Kubics",
      "ST": "Bangkok"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

# Scheduler

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "TH",
      "L": "Bangkok",
      "O": "system:kube-scheduler",
      "OU": "Kubics",
      "ST": "Bangkok"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

