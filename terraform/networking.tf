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

## -- Subnet and Route tabel association
resource "aws_route_table_association" "kube_public_assoc" {
  count          = length(aws_subnet.kube_public_subnet)
  subnet_id      = aws_subnet.kube_public_subnet[count.index].id
  route_table_id = aws_route_table.kube_public_rt.id
}
