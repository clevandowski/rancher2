variable "aws_profile" {
  type = string
  description = "your aws profile here from ~/.aws/credentials"
}

variable "aws_region" {
  type = string
  default = "eu-west-3"
}

variable "aws_instance_type_master" {
  type = string
  default = "m5.xlarge"
}

variable "aws_instance_type_worker" {
  type = string
  default = "m5.xlarge"
}

variable "authorized_ip" {
  type = string
  default = "0.0.0.0/0"
}

variable "egress_ip" {
  type = string
  default = "0.0.0.0/0"
}

variable "aws_vpc_cidr_block" {
  type = string
  default = "10.0.0.0/16"
}

variable "rancher_lb_dns" {
  type = string
  description = "Enregistrement DNS associée à Rancher sur Route53 rancher.mydomain.com"
  default = ""
}

variable "rancher_hosted_zone_id" {
  type = string
  description = "A injecter en fonction d'une hosted zone existante"
  default = ""
}

variable "rancher_id_rsa_pub_path" {
  type = string
  description = "Chemin vers la clé publique utilisé pour se connecter au VMs"
  default = "~/.ssh/id_rsa.pub"
}


# Configure the AWS Provider
provider "aws" {
  profile = var.aws_profile
  version = "~> 2.0"
  region = var.aws_region
}

# Data
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

data "aws_ami" "nat-instance" {
  owners = ["amazon"] # amazon
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat-2018.03.0.20190611-x86_64-ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# https://medium.com/@hmalgewatta/setting-up-an-aws-ec2-instance-with-ssh-access-using-terraform-c336c812322f
resource "aws_key_pair" "rancher2-key-pair" {
  key_name   = "rancher2-key-pair"
  public_key = file(var.rancher_id_rsa_pub_path)
}

# Create a VPC
resource "aws_vpc" "rancher2-vpc" {
  cidr_block = var.aws_vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "rancher2-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "rancher2-igw" {
  vpc_id = aws_vpc.rancher2-vpc.id
  tags = {
    Name = "rancher2-igw"
  }
}

# Internet Gateway route, external public access
resource "aws_route_table" "rancher2-public-to-igw-rt" {
  vpc_id = aws_vpc.rancher2-vpc.id
  route {
    cidr_block = var.egress_ip
    gateway_id = aws_internet_gateway.rancher2-igw.id
  }
  tags = {
    Name = "rancher2-public-to-igw-rt"
    Zone = "Public"
  }
}

/******************
* Bastion
*******************/
resource "aws_subnet" "rancher2-bastion-subnet" {
  # Input: "10.0.0.0/16" => Output: "10.0.0.0/24"
  cidr_block = cidrsubnet(aws_vpc.rancher2-vpc.cidr_block, 8, 0)
  vpc_id = aws_vpc.rancher2-vpc.id
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "rancher2-bastion-subnet"
    Zone = "Public"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}

resource "aws_route_table_association" "rancher2-bastion-to-igw-rta" {
  subnet_id = aws_subnet.rancher2-bastion-subnet.id
  route_table_id = aws_route_table.rancher2-public-to-igw-rt.id
}

resource "aws_security_group" "rancher2-bastion-sg" {
  name = "rancher2-bastion-sg"
  description = "Allow ssh access to connect to private subnet from authorized ips"

  ingress {
    cidr_blocks = [var.authorized_ip]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = [var.egress_ip]
  }

  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [var.egress_ip]
  }
  egress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [var.egress_ip]
  }
  egress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
  }
  egress {
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
  }
  egress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = [var.egress_ip]
  }

  vpc_id = aws_vpc.rancher2-vpc.id

  tags = {
    Name = "rancher2-bastion-sg"
    Zone = "Public"
  }
}

resource "aws_instance" "rancher2-bastion" {
  # this is a special ami preconfigured to do NAT
  # TODO  Cyrille mettre une centos basique à la place (adhérence scripts provisionning)
  ami = data.aws_ami.nat-instance.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.rancher2-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.rancher2-bastion-sg.id]
  subnet_id = aws_subnet.rancher2-bastion-subnet.id
  associate_public_ip_address = true
  source_dest_check = false

  tags = {
    Name = "rancher2-bastion"
    Zone = "Public"
  }
}

#################################
# NAT Gateways (1 per zone)     #
#################################
# Each NAT gateway requires:
# * a public subnet (routed to igw)
# * an elastic ip
# Zone a
resource "aws_subnet" "rancher2-a-public-subnet" {
  # Input: "10.0.0.0/16" => Output: "10.0.4.0/24"
  cidr_block = cidrsubnet(aws_vpc.rancher2-vpc.cidr_block, 8, 4)
  vpc_id = aws_vpc.rancher2-vpc.id
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "rancher2-a-public-subnet"
    Zone = "Public"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}
resource "aws_route_table_association" "rancher2-a-public-subnet-to-igw-rta" {
  subnet_id = aws_subnet.rancher2-a-public-subnet.id
  route_table_id = aws_route_table.rancher2-public-to-igw-rt.id
}
resource "aws_eip" "rancher2-a-ngw-eip" {
  vpc = true
  tags = {
    Name = "rancher2-a-ngw-eip"
  }
}
resource "aws_nat_gateway" "rancher2-a-ngw" {
  allocation_id = aws_eip.rancher2-a-ngw-eip.id
  subnet_id = aws_subnet.rancher2-a-public-subnet.id
  tags = {
    Name = "rancher2-a-ngw"
  }
}
resource "aws_route_table" "rancher2-private-a-to-ngw-rt" {
  vpc_id = aws_vpc.rancher2-vpc.id
  route {
    cidr_block = var.egress_ip
    nat_gateway_id = aws_nat_gateway.rancher2-a-ngw.id
  }
  tags = {
    Name = "rancher2-private-a-to-ngw-rt"
    Zone = "Public"
  }
}
# Zone b
resource "aws_subnet" "rancher2-b-public-subnet" {
  # Input: "10.0.0.0/16" => Output: "10.0.5.0/24"
  cidr_block = cidrsubnet(aws_vpc.rancher2-vpc.cidr_block, 8, 5)
  vpc_id = aws_vpc.rancher2-vpc.id
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "rancher2-b-public-subnet"
    Zone = "Public"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}
resource "aws_route_table_association" "rancher2-b-public-subnet-to-igw-rta" {
  subnet_id = aws_subnet.rancher2-b-public-subnet.id
  route_table_id = aws_route_table.rancher2-public-to-igw-rt.id
}
resource "aws_eip" "rancher2-b-ngw-eip" {
  vpc = true
  tags = {
    Name = "rancher2-b-ngw-eip"
  }
}
resource "aws_nat_gateway" "rancher2-b-ngw" {
  allocation_id = aws_eip.rancher2-b-ngw-eip.id
  subnet_id = aws_subnet.rancher2-b-public-subnet.id
  tags = {
    Name = "rancher2-b-ngw"
  }
}
resource "aws_route_table" "rancher2-private-b-to-ngw-rt" {
  vpc_id = aws_vpc.rancher2-vpc.id
  route {
    cidr_block = var.egress_ip
    nat_gateway_id = aws_nat_gateway.rancher2-b-ngw.id
  }
  tags = {
    Name = "rancher2-private-b-to-ngw-rt"
    Zone = "Public"
  }
}
# Zone c
resource "aws_subnet" "rancher2-c-public-subnet" {
  # Input: "10.0.0.0/16" => Output: "10.0.6.0/24"
  cidr_block = cidrsubnet(aws_vpc.rancher2-vpc.cidr_block, 8, 6)
  vpc_id = aws_vpc.rancher2-vpc.id
  availability_zone = "${var.aws_region}c"
  tags = {
    Name = "rancher2-c-public-subnet"
    Zone = "Public"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}
resource "aws_route_table_association" "rancher2-c-public-subnet-to-igw-rta" {
  subnet_id = aws_subnet.rancher2-c-public-subnet.id
  route_table_id = aws_route_table.rancher2-public-to-igw-rt.id
}
resource "aws_eip" "rancher2-c-ngw-eip" {
  vpc = true
  tags = {
    Name = "rancher2-c-ngw-eip"
  }
}
resource "aws_nat_gateway" "rancher2-c-ngw" {
  allocation_id = aws_eip.rancher2-c-ngw-eip.id
  subnet_id = aws_subnet.rancher2-c-public-subnet.id
  tags = {
    Name = "rancher2-c-ngw"
  }
}
resource "aws_route_table" "rancher2-private-c-to-ngw-rt" {
  vpc_id = aws_vpc.rancher2-vpc.id
  route {
    cidr_block = var.egress_ip
    nat_gateway_id = aws_nat_gateway.rancher2-c-ngw.id
  }
  tags = {
    Name = "rancher2-private-c-to-ngw-rt"
    Zone = "Public"
  }
}

##########################################
# Private Zone rancher2-x-private-subnet #
##########################################
# Zone a
resource "aws_subnet" "rancher2-a-private-subnet" {
  # Input: "10.0.0.0/16" => Output: "10.0.1.0/24"
  cidr_block = cidrsubnet(aws_vpc.rancher2-vpc.cidr_block, 8, 1)
  vpc_id = aws_vpc.rancher2-vpc.id
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "rancher2-a-private-subnet"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}
resource "aws_route_table_association" "rancher2-private-a-subnet-to-ngw-rta" {
  route_table_id = aws_route_table.rancher2-private-a-to-ngw-rt.id
  subnet_id = aws_subnet.rancher2-a-private-subnet.id
}

# Zone b
resource "aws_subnet" "rancher2-b-private-subnet" {
  # Input: "10.0.0.0/16" => Output: "10.0.2.0/24"
  cidr_block = cidrsubnet(aws_vpc.rancher2-vpc.cidr_block, 8, 2)
  vpc_id = aws_vpc.rancher2-vpc.id
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "rancher2-b-private-subnet"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}
resource "aws_route_table_association" "rancher2-private-b-subnet-to-ngw-rta" {
  route_table_id = aws_route_table.rancher2-private-b-to-ngw-rt.id
  subnet_id = aws_subnet.rancher2-b-private-subnet.id
}

# Zone c
resource "aws_subnet" "rancher2-c-private-subnet" {
  # Input: "10.0.0.0/16" => Output: "10.0.3.0/24"
  cidr_block = cidrsubnet(aws_vpc.rancher2-vpc.cidr_block, 8, 3)
  vpc_id = aws_vpc.rancher2-vpc.id
  availability_zone = "${var.aws_region}c"
  tags = {
    Name = "rancher2-c-private-subnet"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}
resource "aws_route_table_association" "rancher2-private-c-subnet-to-ngw-rta" {
  route_table_id = aws_route_table.rancher2-private-c-to-ngw-rt.id
  subnet_id = aws_subnet.rancher2-c-private-subnet.id
}


# Create a Security Group
resource "aws_security_group" "rancher2-sg" {
  name = "rancher2-sg"
  vpc_id = aws_vpc.rancher2-vpc.id
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  // Prometheus node-exporter
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 9796
    to_port = 9796
    protocol = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [var.egress_ip]
  }
  tags = {
    Name = "rancher2-sg"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}


resource "aws_security_group" "rancher2-etcd-sg" {
  name = "rancher2-etcd-sg"
  vpc_id = aws_vpc.rancher2-vpc.id
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 2376
    to_port = 2376
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 2379
    to_port = 2379
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 2380
    to_port = 2380
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 8472
    to_port = 8472
    protocol = "udp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 9099
    to_port = 9099
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 10250
    to_port = 10250
    protocol = "tcp"
  }
  egress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
  }
  egress {
    from_port = 2379
    to_port = 2379
    protocol = "tcp"
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
  }
  egress {
    from_port = 2380
    to_port = 2380
    protocol = "tcp"
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
  }
  egress {
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
  }
  egress {
    from_port = 8472
    to_port = 8472
    protocol = "udp"
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
  }
  egress {
    from_port = 9099
    to_port = 9099
    protocol = "tcp"
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
  }
  tags = {
    Name = "rancher2-etcd-sg"
    Zone = "Private"
#    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}

resource "aws_security_group" "rancher2-controlplane-sg" {
  name = "rancher2-controlplane-sg"
  vpc_id = aws_vpc.rancher2-vpc.id
  ingress {
    cidr_blocks = [var.aws_vpc_cidr_block]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  # Le daemonset cattle-system/cattle-node-agent
  # et le deployment cattle-system/cattle-cluster-agent
  # ont besoin que les ips des instances aws du cluster k8s
  # aient accès au port 443
  ingress {
    // Incoming traffic from NLB does not mask incoming request (so ip from internet)
    cidr_blocks = [var.egress_ip, aws_vpc.rancher2-vpc.cidr_block]
    #cidr_blocks = [var.authorized_ip,var.aws_vpc_cidr_block]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 2376
    to_port = 2376
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 8472
    to_port = 8472
    protocol = "udp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 9099
    to_port = 9099
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 10250
    to_port = 10250
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 10254
    to_port = 10254
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 30000
    to_port = 32767
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 30000
    to_port = 32767
    protocol = "udp"
  }
  egress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
  egress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 2379
    to_port = 2379
    protocol = "tcp"
  }
  egress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 2380
    to_port = 2380
    protocol = "tcp"
  }
  egress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 8472
    to_port = 8472
    protocol = "udp"
  }
  egress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 9099
    to_port = 9099
    protocol = "tcp"
  }
  egress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 10250
    to_port = 10250
    protocol = "tcp"
  }
  egress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 10254
    to_port = 10254
    protocol = "tcp"
  }
  tags = {
    Name = "rancher2-controlplane-sg"
    Zone = "Private"
#    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}

# Create a Security Group
resource "aws_security_group" "rancher2-worker-sg" {
  name = "rancher2-worker-sg"
  vpc_id = aws_vpc.rancher2-vpc.id
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  ingress {
    // Incoming traffic from NLB does not mask incoming request (so ip from internet)
    cidr_blocks = [var.egress_ip, aws_vpc.rancher2-vpc.cidr_block]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 2376
    to_port = 2376
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 8472
    to_port = 8472
    protocol = "udp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 9099
    to_port = 9099
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 10250
    to_port = 10250
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 10254
    to_port = 10254
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 30000
    to_port = 32767
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 30000
    to_port = 32767
    protocol = "udp"
  }
  egress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
  egress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
  }
  egress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 8472
    to_port = 8472
    protocol = "udp"
  }
  egress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 9099
    to_port = 9099
    protocol = "tcp"
  }
  egress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 10254
    to_port = 10254
    protocol = "tcp"
  }
  tags = {
    Name = "rancher2-worker-sg"
    Zone = "Private"
#    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}

resource "aws_security_group" "rancher2-elasticsearch-sg" {
  name = "rancher2-elasticsearch-sg"
  vpc_id = aws_vpc.rancher2-vpc.id
  // ElasticSearch port 9200
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 9200
    to_port = 9200
    protocol = "tcp"
  }
  // ElasticSearch port 9300
  ingress {
    cidr_blocks = [aws_vpc.rancher2-vpc.cidr_block]
    from_port = 9300
    to_port = 9300
    protocol = "tcp"
  }
  tags = {
    Name = "rancher2-worker-sg"
    Zone = "Private"
  }
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
  # subnets = [aws_subnet.rancher2-bastion-subnet.id]
  subnets = [aws_subnet.rancher2-a-public-subnet.id,aws_subnet.rancher2-b-public-subnet.id,aws_subnet.rancher2-c-public-subnet.id]
  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
  tags = {
    Name = "rancher"
    Zone = "Public"
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
resource "aws_route53_record" "rancher_lb_dns" {
  count = var.rancher_hosted_zone_id != "" ? 1 : 0 
  zone_id = var.rancher_hosted_zone_id
  name = var.rancher_lb_dns
  type = "A"
  alias {
    name = aws_lb.rancher2-nlb.dns_name
    zone_id = aws_lb.rancher2-nlb.zone_id
    evaluate_target_health = true
  }
}
# ec2 instances
resource "aws_instance" "rancher2-a-master" {
  ami = data.aws_ami.latest-ubuntu.id
  instance_type = var.aws_instance_type_master
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = aws_key_pair.rancher2-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-etcd-sg.id,aws_security_group.rancher2-controlplane-sg.id]
  subnet_id = aws_subnet.rancher2-a-private-subnet.id
  root_block_device {
    volume_size = 16
  }
  tags = {
    Name = "rancher2-a-master"
    Zone = "Private"
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
  instance_type = var.aws_instance_type_master
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = aws_key_pair.rancher2-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-etcd-sg.id,aws_security_group.rancher2-controlplane-sg.id]
  subnet_id = aws_subnet.rancher2-b-private-subnet.id
  root_block_device {
    volume_size = 16
  }
  tags = {
    Name = "rancher2-b-master"
    Zone = "Private"
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
  instance_type = var.aws_instance_type_master
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = aws_key_pair.rancher2-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-etcd-sg.id,aws_security_group.rancher2-controlplane-sg.id]
  subnet_id = aws_subnet.rancher2-c-private-subnet.id
  root_block_device {
    volume_size = 16
  }
  tags = {
    Name = "rancher2-c-master"
    Zone = "Private"
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
  instance_type = var.aws_instance_type_worker
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = aws_key_pair.rancher2-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-worker-sg.id,aws_security_group.rancher2-elasticsearch-sg.id]
  subnet_id = aws_subnet.rancher2-a-private-subnet.id
  root_block_device {
    volume_size = 32
  }
  tags = {
    Name = "rancher2-a-worker"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
    role_rke = true
    role_etcd = false
    role_controlplane = false
    role_worker = true
  }
}

resource "aws_instance" "rancher2-b-worker" {
  ami = data.aws_ami.latest-ubuntu.id
  instance_type = var.aws_instance_type_worker
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = aws_key_pair.rancher2-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-worker-sg.id,aws_security_group.rancher2-elasticsearch-sg.id]
  subnet_id = aws_subnet.rancher2-b-private-subnet.id
  root_block_device {
    volume_size = 32
  }
  tags = {
    Name = "rancher2-b-worker"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
    role_rke = true
    role_etcd = false
    role_controlplane = false
    role_worker = true
  }
}

resource "aws_instance" "rancher2-c-worker" {
  ami = data.aws_ami.latest-ubuntu.id
  instance_type = var.aws_instance_type_worker
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = aws_key_pair.rancher2-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-worker-sg.id,aws_security_group.rancher2-elasticsearch-sg.id]
  subnet_id = aws_subnet.rancher2-c-private-subnet.id
  root_block_device {
    volume_size = 32
  }
  tags = {
    Name = "rancher2-c-worker"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
    role_rke = true
    role_etcd = false
    role_controlplane = false
    role_worker = true
  }
}


output "inventory" {
  value = <<INVENTORY
all:
  children:
    bastion:
      hosts:
        rancher2-bastion:
          ansible_host: ${aws_instance.rancher2-bastion.public_ip}
      vars:
        ansible_user: ec2-user
    rancher:
      hosts:
        rancher2-a-master:
          ansible_host: ${aws_instance.rancher2-a-master.private_ip}
          private_dns: ${aws_instance.rancher2-a-master.private_dns}
          private_ip: ${aws_instance.rancher2-a-master.private_ip}
        rancher2-b-master:
          ansible_host: ${aws_instance.rancher2-b-master.private_ip}
          private_dns: ${aws_instance.rancher2-b-master.private_dns}
          private_ip: ${aws_instance.rancher2-b-master.private_ip}
        rancher2-c-master:
          ansible_host: ${aws_instance.rancher2-c-master.private_ip}
          private_dns: ${aws_instance.rancher2-c-master.private_dns}
          private_ip: ${aws_instance.rancher2-c-master.private_ip}
        rancher2-a-worker:
          ansible_host: ${aws_instance.rancher2-a-worker.private_ip}
          private_dns: ${aws_instance.rancher2-a-worker.private_dns}
          private_ip: ${aws_instance.rancher2-a-worker.private_ip}
        rancher2-b-worker:
          ansible_host: ${aws_instance.rancher2-b-worker.private_ip}
          private_dns: ${aws_instance.rancher2-b-worker.private_dns}
          private_ip: ${aws_instance.rancher2-b-worker.private_ip}
        rancher2-c-worker:
          ansible_host: ${aws_instance.rancher2-c-worker.private_ip}
          private_dns: ${aws_instance.rancher2-c-worker.private_dns}
          private_ip: ${aws_instance.rancher2-c-worker.private_ip}
      vars:
        ansible_user: ubuntu
  vars:
    ansible_connection: ssh
    ansible_port: 22

INVENTORY
}

output "rancher-template" {
  value = <<RANCHER_TEMPLATE
cloud_provider:
  _comment: cf https://github.com/rancher/rancher/issues/24329
  awsCloudProvider:
    global:
      disable-security-group-ingress: false
      disable-strict-zone-check: false
  name: aws
nodes:
- address: ${aws_instance.rancher2-a-master.private_ip}
  hostname_override: rancher2-a-master
  role:
  - controlplane
  - etcd
  - worker
  ssh_key_path: ${var.rancher_id_rsa_pub_path}
  user: ubuntu
- address: ${aws_instance.rancher2-b-master.private_ip}
  hostname_override: rancher2-b-master
  role:
  - controlplane
  - etcd
  - worker
  ssh_key_path: ~/.ssh/aws
  ssh_key_path: ${var.rancher_id_rsa_pub_path}
- address: ${aws_instance.rancher2-c-master.private_ip}
  hostname_override: rancher2-c-master
  role:
  - controlplane
  - etcd
  - worker
  ssh_key_path: ${var.rancher_id_rsa_pub_path}
  user: ubuntu
- address: ${aws_instance.rancher2-a-worker.private_ip}
  hostname_override: rancher2-a-worker
  labels:
    elasticsearch: reserved
  role:
  - worker
  ssh_key_path: ~/.ssh/aws
  taints:
  - effect: NoSchedule
    key: node.elasticsearch.io/unschedulable
    value: ''
  user: ubuntu
- address: ${aws_instance.rancher2-b-worker.private_ip}
  hostname_override: rancher2-b-worker
  labels:
    elasticsearch: reserved
  role:
  - worker
  ssh_key_path: ${var.rancher_id_rsa_pub_path}
  taints:
  - effect: NoSchedule
    key: node.elasticsearch.io/unschedulable
    value: ''
  user: ubuntu
- address: ${aws_instance.rancher2-c-worker.private_ip}
  hostname_override: rancher2-c-worker
  labels:
    elasticsearch: reserved
  role:
  - worker
  ssh_key_path: ${var.rancher_id_rsa_pub_path}
  taints:
  - effect: NoSchedule
    key: node.elasticsearch.io/unschedulable
    value: ''
  user: ubuntu
services:
  etcd:
    creation: 6h
    retention: 24h
    snapshot: true

bastion_host:
  address: ${aws_instance.rancher2-bastion.public_ip}
  hostname_override: rancher2-bastion
  ssh_key_path: ${var.rancher_id_rsa_pub_path}
  user: ec2-user

  RANCHER_TEMPLATE
}
