# --- Instances ---
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

# Add routing for POD-CIDR to the corresponding worker

resource "aws_route" "kube_pod_cidr_route" {
  count = length(aws_instance.kube_worker)

  route_table_id         = aws_route_table.kube_public_rt.id
  destination_cidr_block = aws_instance.kube_worker[count.index].tags["Pod_Cidr"]
  instance_id            = aws_instance.kube_worker[count.index].id

}