# 03. Compute ressources

We will set up our cloud infrastructure on AWS with a terraform script.

We will deploy the following infrastructure:

1. VPC
2. Internet Gateway
3. As many subnets as different availability zones there are inside the region
4. Public security group that allows incoming connections from 0.0.0.0 on ports 80,443 and 22 (NOT SUITABLE FOR PRODUCTION)
5. Routing table and routing table subnet associations
6. One key pair for all the instances (NOT SUITABLE FOR PRODUCTION)
7. One worker instance per subnet
8. One controller instance per subnet
9. One load balancer instance
10. Routing rules for finding PODs

## VARIABLES

You can use the following variable.tf file
```
variable "aws_region" {
  default = "eu-central-1"
}
variable "aws_profile" {
  default = "kube-the-hard-way"
}
variable "ami_type" {
  # Ubuntu 16.04 ami
  default = "ami-0cc0a36f626a4fdf5"
}
variable "instance_type" {
  default = "t2.micro"
}
variable "key_name" {
  default = "kube_the_hard_way"
}
variable "public_key_path" {
  default = "~/.ssh/kube_the_hard_way.pub"
}
```

## Povider

```
terraform {
  required_version = "0.12.19"
}

provider "aws" {
  version = "2.46.0"
  region  = var.aws_region
  profile = var.aws_profile
}
```

## VPC

```
## -- VPC --
resource "aws_vpc" "kube_vpc" {
  cidr_block           = "10.240.0.0/24"
  enable_dns_hostnames = true
}
```

## IGW

```
## -- Internet Gateway --
resource "aws_internet_gateway" "kube_igw" {

  vpc_id = aws_vpc.kube_vpc.id

  tags = {
    Name = "kube_igw"
  }
}
```

## Subnets

```
## -- Public subnets --
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "kube_public_subnet" {
  count = length(data.aws_availability_zones.available.names)

  vpc_id                  = aws_vpc.kube_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.kube_vpc.cidr_block, 4, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "kube_public_${count.index}_sn"
  }
}
```

## Security groups 

```
## -- Security groups --
resource "aws_security_group" "kube_web_open_sg" {
  vpc_id      = aws_vpc.kube_vpc.id
  description = "Security group for open to the internet"
  name        = "kube_web_open_sg"

  #SSH TO CONNECT TO INSTANCES
  ingress {
    description = "Incoming ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #All open for self
  ingress {
    description = "All open for my SG"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    self        = true
  }

  ingress {
    description = "All open for my SG"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["10.200.0.0/16"]
  }

  #FOR LOAD BALANCER INCOMING 
  ingress {
    description = "Standard https incoming"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all ports and protocols to go out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

## Routing table

```
## -- Public routing table
resource "aws_route_table" "kube_public_rt" {
  vpc_id = aws_vpc.kube_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kube_igw.id
  }

  tags = {
    Name = "kube_public_rt"
  }
}


## -- Subnet and Route tabel association
resource "aws_route_table_association" "kube_public_assoc" {
  count          = length(aws_subnet.kube_public_subnet)
  subnet_id      = aws_subnet.kube_public_subnet[count.index].id
  route_table_id = aws_route_table.kube_public_rt.id
}
```

## Key 

First we create the key

```
ssh-keygen -t rsa -f ~/.ssh/kube_the_hard_way
```

```
resource "aws_key_pair" "kube_auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}
```
## Worker instances

```
resource "aws_instance" "kube_worker" {
  count = length(aws_subnet.kube_public_subnet)

  instance_type = var.instance_type
  ami           = var.ami_type

  tags = {
    Name     = "kube_worker_${count.index}_instance"
    Pod_Cidr = "10.200.${count.index}.0/24"
  }

  user_data = "name=worker-${count.index}|pod-cidr=10.200.${count.index}.0/24"

  key_name               = aws_key_pair.kube_auth.id
  vpc_security_group_ids = [aws_security_group.kube_web_open_sg.id]
  subnet_id              = aws_subnet.kube_public_subnet[count.index].id
  source_dest_check      = false

}
```

## Controller instances

```
resource "aws_instance" "kube_controller" {
  count = length(aws_subnet.kube_public_subnet)

  instance_type = var.instance_type
  ami           = var.ami_type

  tags = {
    Name = "kube_controller_${count.index}_instance"
  }
  user_data              = "name=controller-${count.index}"
  key_name               = aws_key_pair.kube_auth.id
  vpc_security_group_ids = [aws_security_group.kube_web_open_sg.id]
  subnet_id              = aws_subnet.kube_public_subnet[count.index].id
}
```

## Load Balancer, target groups and listeners

```
resource "aws_lb" "kube_loadbalancer" {
  name               = "kube-loadbalancer"
  internal           = false
  load_balancer_type = "network"
  subnets            = [for subnet in aws_subnet.kube_public_subnet : subnet.id]

  enable_deletion_protection = false

  depends_on = [aws_instance.kube_controller]
}

resource "aws_lb_target_group" "kube_controller_target_group" {
  name     = "kube-controller-tg"
  port     = 6443
  protocol = "TCP"
  vpc_id   = aws_vpc.kube_vpc.id
}

resource "aws_lb_target_group_attachment" "hf_lb_instance_attachment" {
  count = length(aws_instance.kube_controller)

  target_group_arn = aws_lb_target_group.kube_controller_target_group.arn
  target_id        = aws_instance.kube_controller[count.index].id
  port             = 6443
}

resource "aws_lb_listener" "kube_port443_listener" {
  load_balancer_arn = aws_lb.kube_loadbalancer.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kube_controller_target_group.arn
  }
}
```

## Routes for finding pods

# Add routing for POD-CIDR to the corresponding worker

```
resource "aws_route" "kube_pod_cidr_route" {
  count = length(aws_instance.kube_worker)

  route_table_id         = aws_route_table.kube_public_rt.id
  destination_cidr_block = aws_instance.kube_worker[count.index].tags["Pod_Cidr"]
  instance_id            = aws_instance.kube_worker[count.index].id

}
```

## Test

Do a 

```
terraform init
```