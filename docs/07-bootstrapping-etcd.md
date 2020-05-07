# Bootstrapping the etcd Cluster

Kubernetes components are stateless and store cluster state in [etcd](https://github.com/etcd-io/etcd). In this lab you will bootstrap a three node etcd cluster and configure it for high availability and secure remote access.

You can automate this step by running:
```
cd tmp
../scripts/07_bootsrap_etcd_cluster.sh
```

## Prerequisites

The commands in this lab must be run on each controller instance.

Remember to log-in to AWS:

```
make aws_login
```

First get the ETCD cluster setting before connecting to any instance and list all IPs to connect

```
{
PUBLIC_CONTROLLER_IPS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance"\
 "Name=instance-state-name,Values=running" --profile=default --region=ap-southeast-1 --query\
 "Reservations[].Instances[].PublicIpAddress")

PRIVATE_CONTROLLER_IPS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance"\
 "Name=instance-state-name,Values=running" --profile=default --region=ap-southeast-1 --query\
 "Reservations[].Instances[].PrivateIpAddress")

PRIVATE_DNS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance"\
 "Name=instance-state-name,Values=running" --profile=default --region=ap-southeast-1 --query\
 "Reservations[].Instances[].PrivateDnsName")

PUBLIC_WORKER_IPS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_worker_*_instance"\
 "Name=instance-state-name,Values=running" --profile=default --region=ap-southeast-1 --query\
 "Reservations[].Instances[].PublicIpAddress" | jq -r ".[]")

PUBLIC_CONTROLLER_IPS=($(echo $PUBLIC_CONTROLLER_IPS_RAW | jq -r ".[]"))

CLUSTER_SETTING=""
ETCD_CLUSTER_SETTING=""
declare -i i=0
for ip_address in $PUBLIC_CONTROLLER_IPS; do
  CLUSTER_SETTING="${CLUSTER_SETTING},$(echo $PRIVATE_DNS_RAW | jq -r '.['${i}']' | cut -d'.' -f1)=https://$(echo $PRIVATE_CONTROLLER_IPS_RAW | jq -r '.['${i}']'):2380"
  ETCD_CLUSTER_SETTING="${ETCD_CLUSTER_SETTING},https://$(echo $PRIVATE_CONTROLLER_IPS_RAW | jq -r '.['${i}']'):2379"
  i=$i+1
done

ETCD_CLUSTER_SETTING=${ETCD_CLUSTER_SETTING:1}
CLUSTER_SETTING=${CLUSTER_SETTING:1}

echo "CLUSTER_SETTING="$CLUSTER_SETTING
echo "PUBLIC_IPs="$PUBLIC_CONTROLLER_IPS
}
```

Then connect to each instance:

```
ssh -i ~/.ssh/id_rsa ubuntu@THE_IP
```

### Running commands on all intances with Ansible

We will use ansible to run the command.

On your local machine do the following:

First create the host inventory file to know where to connect.

```
{                                
cat <<EOF > kube_full_inventory.yml
---        
all:       
  children:
    
    controller:                           
      hosts:                                                          
$(declare -i i=0
for ip in $PUBLIC_CONTROLLER_IPS; do
echo "        "${ip}:
echo "          "priv_ip: $(echo $PRIVATE_CONTROLLER_IPS_RAW | jq -r '.['${i}']')
i=$i+1 
done)
      vars:
        ansible_python_interpreter: /usr/bin/python3
        cluster_setting: $CLUSTER_SETTING
        etcd_cluster: $ETCD_CLUSTER_SETTING

    worker:                           
      hosts:                                                          
$(for ip in $PUBLIC_WORKER_IPS; do
echo "        "${ip}:
done)
      vars:
        ansible_python_interpreter: /usr/bin/python3
                                                                             
EOF
}
```

Now create a Yaml file to run all ansible commands

```
touch 07_bootstrap_etcd_cluster.yml
```

And copy this at the top of the file:

```
---
- hosts: controller
  remote_user: ubuntu
  tasks:
````

## Bootstrapping an etcd Cluster Member

### Download and Install the etcd Binaries

Download the official etcd release binaries from the [etcd](https://github.com/etcd-io/etcd) GitHub project:

SSH:

```
wget -q --show-progress --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.4.0/etcd-v3.4.0-linux-amd64.tar.gz"
```

Extract and install the `etcd` server and the `etcdctl` command line utility:

```
{
  tar -xvf etcd-v3.4.0-linux-amd64.tar.gz
  sudo mv etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/
}
```

ANSIBLE: (Ensure the tabs stay as they are, they are important)
```
    - name: Get etcd binaries
      unarchive:
        src: https://github.com/etcd-io/etcd/releases/download/v3.4.0/etcd-v3.4.0-linux-amd64.tar.gz
        dest: /usr/local/bin/
        remote_src: yes
      become: yes
    
    - name: Move etcd binaries
      shell: mv /usr/local/bin/etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/ && rm -rf /usr/local/bin/etcd-v3.4.0-linux-amd64/
      become: yes
```

### Configure the etcd Server

Copy Certificate files

SSH:
```
{
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
}
```

ANSIBLE:
```
    - name: Creates directory /etc/etcd
      file:
        path: /etc/etcd
        state: directory
      become: yes

    - name: Creates directory /var/lib/etcd
      file:
        path: /var/lib/etcd
        state: directory
      become: yes
    
    - name: Move etcd certificates
      shell: cp /home/ubuntu/ca.pem /home/ubuntu/kubernetes-key.pem /home/ubuntu/kubernetes.pem /etc/etcd/
      become: yes
```

The instance internal IP address will be used to serve client requests and communicate with etcd cluster peers. Retrieve the internal IP address for the current compute instance:

```
INTERNAL_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
```

Each etcd member must have a unique name within an etcd cluster. Set the etcd name to match the public hostname of the current compute instance:

```
ETCD_NAME=$(hostname)
```

Copy the CLUSTER_SETTING variable that you retreived before
```
CLUSTER_SETTING="PASTE_HERE_YOUR_STUFF_WITHIN"
```

Create the `etcd.service` systemd unit file:

SSH:

```
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${CLUSTER_SETTING} \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

ANSIBLE:
You can use the provided 07_etcd_service.template file to copy it to the controller instances

```
    - name: Create service file
      template:
        src: "07_etcd_service.template"
        dest: "/etc/systemd/system/etcd.service"
      become: yes
```
### Start the etcd Server

SSH:

```
{
  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl stop etcd
  sudo systemctl start etcd
}
```

ANSIBLE:

```
    - name: Start the etcd Server
      shell: |
        systemctl daemon-reload 
        systemctl enable etcd 
        sudo systemctl stop etcd 
        systemctl start etcd
      become: yes
```

> Remember to run the above commands on each controller node: `controller-0`, `controller-1`, and `controller-2`.

## Verification

List the etcd cluster members within any of the ec2 machines:

```
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
```

> output should look something like this

```
1f7d3e35df13f868, started, ip-10-240-0-40, https://10.240.0.40:2380, https://10.240.0.40:2379, false
50c9ffea3001b48c, started, ip-10-240-0-21, https://10.240.0.21:2380, https://10.240.0.21:2379, false
ffed16798470cab5, started, ip-10-240-0-11, https://10.240.0.11:2380, https://10.240.0.11:2379, false
```

Next: [Bootstrapping the Kubernetes Control Plane](08-bootstrapping-kubernetes-controllers.md)