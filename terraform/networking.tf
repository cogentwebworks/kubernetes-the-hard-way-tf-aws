# --- Networking ---

## -- VPC --
resource "aws_vpc" "kube_vpc" {
  cidr_block           = "10.240.0.0/24"
  enable_dns_hostnames = true
}

## -- Internet Gateway --
resource "aws_internet_gateway" "kube_igw" {

  vpc_id = aws_vpc.kube_vpc.id

  tags = {
    Name = "kube_igw"
  }
}

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

## -- Subnet and Route tabel association
resource "aws_route_table_association" "kube_public_assoc" {
  count          = length(aws_subnet.kube_public_subnet)
  subnet_id      = aws_subnet.kube_public_subnet[count.index].id
  route_table_id = aws_route_table.kube_public_rt.id
}
