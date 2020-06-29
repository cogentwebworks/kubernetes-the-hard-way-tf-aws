# --- Firewall ---

## -- Security groups --
resource "aws_security_group" "kube_web_open_sg" {
  vpc_id      = aws_vpc.kube_vpc.id
  description = "Security group for open to the internet"
  name        = "kube_web_open_sg"

  #SSH TO CONNECT TO INSTANCES
  ingress {
    description      = "Incoming ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
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

  #FOR httpd INCOMMING
  ingress {
    from_port        = 80
    description      = "Internet Ingress"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "tcp"
    to_port          = 80
  }

  ingress {
    from_port        = 443
    description      = "Internet Ingress"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "tcp"
    to_port          = 443
  }

  #FOR LOAD BALANCER INCOMING 
  ingress {
    description      = "Standard API https incoming"
    from_port        = 6443
    to_port          = 6443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Allow all ports and protocols to go out"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

