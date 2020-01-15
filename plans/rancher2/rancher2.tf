variable "aws_profile" {
  type = string
  # la-fonciere-numerique
  # default = "lafonciere"
  # ops-zenika
  default = "clevandowski-ops-zenika"
}

variable "aws_region" {
  type = string
  # la-fonciere-numerique
  # default = "eu-west-3"
  # ops-zenika
  default = "eu-central-1"
}

data "aws_ami" "latest-ubuntu" {
  owners = ["099720109477"] # Canonical
  most_recent = true
  filter {
      name   = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
  filter {
      name   = "virtualization-type"
      values = ["hvm"]
  }
}

variable "aws_instance_type" {
  type = string
  default = "m5.xlarge"
}

# Configure the AWS Provider
provider "aws" {
  shared_credentials_file = "/home/cyrille/.aws/credentials"
  profile = var.aws_profile
  version = "~> 2.0"
  region = var.aws_region
}

# https://medium.com/@hmalgewatta/setting-up-an-aws-ec2-instance-with-ssh-access-using-terraform-c336c812322f

resource "aws_key_pair" "rancher2-key-pair" {
  key_name   = "rancher2-key-pair"
  public_key = file("~/.ssh/id_rsa.pub")
}

# Create a VPC
resource "aws_vpc" "rancher2-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "rancher2-vpc"
  }
}

# Create a Subnet in zone "a"
resource "aws_subnet" "rancher2-a-subnet" {
  # Input: "10.0.0.0/16" => Output: "10.0.0.0/20"
  cidr_block = cidrsubnet(aws_vpc.rancher2-vpc.cidr_block, 4, 0)
  vpc_id = aws_vpc.rancher2-vpc.id
#  availability_zone = "eu-west-3a"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "rancher2-a-subnet"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}

# Create a Subnet in zone "b"
resource "aws_subnet" "rancher2-b-subnet" {
  # Input: "10.0.0.0/16" => Output: "10.0.16.0/20"
  cidr_block = cidrsubnet(aws_vpc.rancher2-vpc.cidr_block, 4, 1)
  vpc_id = aws_vpc.rancher2-vpc.id
#  availability_zone = "eu-west-3b"
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "rancher2-b-subnet"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}

# Create a Subnet in zone "c"
resource "aws_subnet" "rancher2-c-subnet" {
  # Input: "10.0.0.0/16" => Output: "10.0.32.0/20"
  cidr_block = cidrsubnet(aws_vpc.rancher2-vpc.cidr_block, 4, 2)
  vpc_id = aws_vpc.rancher2-vpc.id
#  availability_zone = "eu-west-3c"
  availability_zone = "${var.aws_region}c"
  tags = {
    Name = "rancher2-c-subnet"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}

# Create a Security Group
resource "aws_security_group" "rancher2-sg" {
  name = "rancher2-sg"
  vpc_id = aws_vpc.rancher2-vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  // Prometheus node-exporter
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 9796
    to_port = 9796
    protocol = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "rancher2-sg"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}

resource "aws_security_group" "rancher2-etcd-sg" {
  name = "rancher2-etcd-sg"
  vpc_id = aws_vpc.rancher2-vpc.id
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 2376
    to_port = 2376
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 2379
    to_port = 2379
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 2380
    to_port = 2380
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 8472
    to_port = 8472
    protocol = "udp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 9099
    to_port = 9099
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 10250
    to_port = 10250
    protocol = "tcp"
  }
  egress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  egress {
    from_port = 2379
    to_port = 2379
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  egress {
    from_port = 2380
    to_port = 2380
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  egress {
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  egress {
    from_port = 8472
    to_port = 8472
    protocol = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  egress {
    from_port = 9099
    to_port = 9099
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  tags = {
    Name = "rancher2-etcd-sg"
#    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}

resource "aws_security_group" "rancher2-controlplane-sg" {
  name = "rancher2-controlplane-sg"
  vpc_id = aws_vpc.rancher2-vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 2376
    to_port = 2376
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 8472
    to_port = 8472
    protocol = "udp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 9099
    to_port = 9099
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 10250
    to_port = 10250
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 10254
    to_port = 10254
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 30000
    to_port = 32767
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 30000
    to_port = 32767
    protocol = "udp"
  }
  egress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 2379
    to_port = 2379
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 2380
    to_port = 2380
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 8472
    to_port = 8472
    protocol = "udp"
  }
  egress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 9099
    to_port = 9099
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 10250
    to_port = 10250
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 10254
    to_port = 10254
    protocol = "tcp"
  }
  tags = {
    Name = "rancher2-controlplane-sg"
#    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}

# Create a Security Group
resource "aws_security_group" "rancher2-worker-sg" {
  name = "rancher2-worker-sg"
  vpc_id = aws_vpc.rancher2-vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 2376
    to_port = 2376
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 8472
    to_port = 8472
    protocol = "udp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 9099
    to_port = 9099
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 10250
    to_port = 10250
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 10254
    to_port = 10254
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 30000
    to_port = 32767
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port = 30000
    to_port = 32767
    protocol = "udp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 8472
    to_port = 8472
    protocol = "udp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 9099
    to_port = 9099
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 10254
    to_port = 10254
    protocol = "tcp"
  }
  tags = {
    Name = "rancher2-worker-sg"
#    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}

resource "aws_internet_gateway" "rancher2-gw" {
  vpc_id = aws_vpc.rancher2-vpc.id
  tags = {
    Name = "rancher2-gw"
  }
}

resource "aws_route_table" "rancher2-rt" {
  vpc_id = aws_vpc.rancher2-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rancher2-gw.id
  }
  tags = {
    Name = "rancher2-rt"
  }
}

resource "aws_main_route_table_association" "rancher2-mrta" {
  vpc_id = aws_vpc.rancher2-vpc.id
  route_table_id = aws_route_table.rancher2-rt.id
}

resource "aws_lb_target_group" "rancher2-tcp-80-tg" {
  name = "rancher2-tcp-80-tg"
  port = 80
  protocol = "TCP"
  vpc_id = aws_vpc.rancher2-vpc.id
  target_type = "instance"
  health_check {
    protocol = "HTTP"
    path = "/healthz"
    port = "traffic-port"
    healthy_threshold = 3
    unhealthy_threshold = 3
    timeout = 6
    interval = 10
    matcher = "200-399"
  }
}

resource "aws_lb_target_group" "rancher2-tcp-443-tg" {
  name = "rancher2-tcp-443-tg"
  port = 443
  protocol = "TCP"
  vpc_id = aws_vpc.rancher2-vpc.id
  target_type = "instance"
  health_check {
    protocol = "HTTP"
    path = "/healthz"
    port = "traffic-port"
    healthy_threshold = 3
    unhealthy_threshold = 3
    timeout = 6
    interval = 10
    matcher = "200-399"
  }
}

resource "aws_lb" "rancher2-nlb" {
  name = "rancher2-nlb"
  load_balancer_type = "network"
  internal = false
  subnets = [aws_subnet.rancher2-a-subnet.id,aws_subnet.rancher2-b-subnet.id,aws_subnet.rancher2-c-subnet.id]
  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
  tags = {
    Name = "rancher"
  }
}
resource "aws_lb_listener" "rancher2-tcp-443-nlb-listener" {
  load_balancer_arn = aws_lb.rancher2-nlb.arn
  protocol = "TCP"
  port = "443"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.rancher2-tcp-443-tg.arn
  }
}
resource "aws_lb_listener" "rancher2-tcp-80-nlb-listener" {
  load_balancer_arn = aws_lb.rancher2-nlb.arn
  protocol = "TCP"
  port = "80"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.rancher2-tcp-80-tg.arn
  }
}
# ec2 instances
resource "aws_instance" "rancher2-a-master" {
  ami = data.aws_ami.latest-ubuntu.id
  instance_type = var.aws_instance_type
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = "rancher2-key-pair"
  security_groups = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-etcd-sg.id,aws_security_group.rancher2-controlplane-sg.id]
  subnet_id = aws_subnet.rancher2-a-subnet.id
  associate_public_ip_address = true
  root_block_device {
    volume_size = 16
  }
  tags = {
    Name = "rancher2-a-master"
    "kubernetes.io/cluster/rancher-master" = "owned"
    role_rke = true
    role_etcd = true
    role_controlplane = true
    role_worker = false
  }
}
resource "aws_lb_target_group_attachment" "rancher2-a-master-tcp-80-tga" {
  target_group_arn = aws_lb_target_group.rancher2-tcp-80-tg.arn
  target_id = aws_instance.rancher2-a-master.id
  port = 80
}
resource "aws_lb_target_group_attachment" "rancher2-a-master-tcp-443-tga" {
  target_group_arn = aws_lb_target_group.rancher2-tcp-443-tg.arn
  target_id = aws_instance.rancher2-a-master.id
  port = 443
}

resource "aws_instance" "rancher2-b-master" {
  ami = data.aws_ami.latest-ubuntu.id
  instance_type = var.aws_instance_type
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = "rancher2-key-pair"
  security_groups = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-etcd-sg.id,aws_security_group.rancher2-controlplane-sg.id]
  subnet_id = aws_subnet.rancher2-b-subnet.id
  associate_public_ip_address = true
  root_block_device {
    volume_size = 16
  }
  tags = {
    Name = "rancher2-b-master"
    "kubernetes.io/cluster/rancher-master" = "owned"
    role_rke = true
    role_etcd = true
    role_controlplane = true
    role_worker = false
  }
}
resource "aws_lb_target_group_attachment" "rancher2-b-master-tcp-80-tga" {
  target_group_arn = aws_lb_target_group.rancher2-tcp-80-tg.arn
  target_id = aws_instance.rancher2-b-master.id
  port = 80
}
resource "aws_lb_target_group_attachment" "rancher2-b-master-tcp-443-tga" {
  target_group_arn = aws_lb_target_group.rancher2-tcp-443-tg.arn
  target_id = aws_instance.rancher2-b-master.id
  port = 443
}

resource "aws_instance" "rancher2-c-master" {
  ami = data.aws_ami.latest-ubuntu.id
  instance_type = var.aws_instance_type
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = "rancher2-key-pair"
  security_groups = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-etcd-sg.id,aws_security_group.rancher2-controlplane-sg.id]
  subnet_id = aws_subnet.rancher2-c-subnet.id
  associate_public_ip_address = true
  root_block_device {
    volume_size = 16
  }
  tags = {
    Name = "rancher2-c-master"
    "kubernetes.io/cluster/rancher-master" = "owned"
    role_rke = true
    role_etcd = true
    role_controlplane = true
    role_worker = false
  }
}
resource "aws_lb_target_group_attachment" "rancher2-c-master-tcp-80-tga" {
  target_group_arn = aws_lb_target_group.rancher2-tcp-80-tg.arn
  target_id = aws_instance.rancher2-c-master.id
  port = 80
}
resource "aws_lb_target_group_attachment" "rancher2-c-master-tcp-443-tga" {
  target_group_arn = aws_lb_target_group.rancher2-tcp-443-tg.arn
  target_id = aws_instance.rancher2-c-master.id
  port = 443
}

resource "aws_instance" "rancher2-a-worker" {
  ami = data.aws_ami.latest-ubuntu.id
  instance_type = var.aws_instance_type
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = "rancher2-key-pair"
  security_groups = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-worker-sg.id]
  subnet_id = aws_subnet.rancher2-a-subnet.id
  associate_public_ip_address = true
  root_block_device {
    volume_size = 32
  }
  tags = {
    Name = "rancher2-a-worker"
    "kubernetes.io/cluster/rancher-master" = "owned"
    role_rke = true
    role_etcd = false
    role_controlplane = false
    role_worker = true
  }
}