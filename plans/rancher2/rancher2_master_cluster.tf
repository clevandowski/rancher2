##########################################
# Private Zone rancher2-x-private-subnet #
##########################################

variable "rancher2-lb-dns" {
  type = string
  description = "Enregistrement DNS associée à Rancher sur Route53 rancher.mydomain.com"
  default = ""
}

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
  depends_on = [
    aws_route_table_association.rancher2-a-public-subnet-to-igw-rta,
    aws_route_table_association.rancher2-b-public-subnet-to-igw-rta,
    aws_route_table_association.rancher2-c-public-subnet-to-igw-rta
  ]
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
resource "aws_route53_record" "rancher2-lb-dns" {
  count = var.rancher2-hosted-zone-id != "" ? 1 : 0
  zone_id = var.rancher2-hosted-zone-id
  name = var.rancher2-lb-dns
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
    cluster = "rancher2"
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
    cluster = "rancher2"
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
    cluster = "rancher2"
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
    cluster = "rancher2"
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
    cluster = "rancher2"
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
    cluster = "rancher2"
  }
}


# output "inventory" {
#   value = <<INVENTORY
# all:
#   children:
#     bastion:
#       hosts:
#         rancher2-bastion:
#           ansible_host: ${aws_instance.rancher2-bastion.public_ip}
#       vars:
#         ansible_user: ec2-user
#     rancher:
#       hosts:
#         rancher2-a-master:
#           ansible_host: ${aws_instance.rancher2-a-master.private_ip}
#           private_dns: ${aws_instance.rancher2-a-master.private_dns}
#           private_ip: ${aws_instance.rancher2-a-master.private_ip}
#         rancher2-b-master:
#           ansible_host: ${aws_instance.rancher2-b-master.private_ip}
#           private_dns: ${aws_instance.rancher2-b-master.private_dns}
#           private_ip: ${aws_instance.rancher2-b-master.private_ip}
#         rancher2-c-master:
#           ansible_host: ${aws_instance.rancher2-c-master.private_ip}
#           private_dns: ${aws_instance.rancher2-c-master.private_dns}
#           private_ip: ${aws_instance.rancher2-c-master.private_ip}
#         rancher2-a-worker:
#           ansible_host: ${aws_instance.rancher2-a-worker.private_ip}
#           private_dns: ${aws_instance.rancher2-a-worker.private_dns}
#           private_ip: ${aws_instance.rancher2-a-worker.private_ip}
#         rancher2-b-worker:
#           ansible_host: ${aws_instance.rancher2-b-worker.private_ip}
#           private_dns: ${aws_instance.rancher2-b-worker.private_dns}
#           private_ip: ${aws_instance.rancher2-b-worker.private_ip}
#         rancher2-c-worker:
#           ansible_host: ${aws_instance.rancher2-c-worker.private_ip}
#           private_dns: ${aws_instance.rancher2-c-worker.private_dns}
#           private_ip: ${aws_instance.rancher2-c-worker.private_ip}
#       vars:
#         ansible_user: ubuntu
#   vars:
#     ansible_connection: ssh
#     ansible_port: 22

# INVENTORY
# }

# output "rancher-template" {
#   value = <<RANCHER_TEMPLATE
# cloud_provider:
#   _comment: cf https://github.com/rancher/rancher/issues/24329
#   awsCloudProvider:
#     global:
#       disable-security-group-ingress: false
#       disable-strict-zone-check: false
#   name: aws
# nodes:
# - address: ${aws_instance.rancher2-a-master.private_ip}
#   hostname_override: rancher2-a-master
#   role:
#   - controlplane
#   - etcd
#   - worker
#   ssh_key_path: ${var.rancher2-id-rsa-pub-path}
#   user: ubuntu
# - address: ${aws_instance.rancher2-b-master.private_ip}
#   hostname_override: rancher2-b-master
#   role:
#   - controlplane
#   - etcd
#   - worker
#   ssh_key_path: ~/.ssh/aws
#   ssh_key_path: ${var.rancher2-id-rsa-pub-path}
# - address: ${aws_instance.rancher2-c-master.private_ip}
#   hostname_override: rancher2-c-master
#   role:
#   - controlplane
#   - etcd
#   - worker
#   ssh_key_path: ${var.rancher2-id-rsa-pub-path}
#   user: ubuntu
# - address: ${aws_instance.rancher2-a-worker.private_ip}
#   hostname_override: rancher2-a-worker
#   labels:
#     elasticsearch: reserved
#   role:
#   - worker
#   ssh_key_path: ~/.ssh/aws
#   taints:
#   - effect: NoSchedule
#     key: node.elasticsearch.io/unschedulable
#     value: ''
#   user: ubuntu
# - address: ${aws_instance.rancher2-b-worker.private_ip}
#   hostname_override: rancher2-b-worker
#   labels:
#     elasticsearch: reserved
#   role:
#   - worker
#   ssh_key_path: ${var.rancher2-id-rsa-pub-path}
#   taints:
#   - effect: NoSchedule
#     key: node.elasticsearch.io/unschedulable
#     value: ''
#   user: ubuntu
# - address: ${aws_instance.rancher2-c-worker.private_ip}
#   hostname_override: rancher2-c-worker
#   labels:
#     elasticsearch: reserved
#   role:
#   - worker
#   ssh_key_path: ${var.rancher2-id-rsa-pub-path}
#   taints:
#   - effect: NoSchedule
#     key: node.elasticsearch.io/unschedulable
#     value: ''
#   user: ubuntu
# services:
#   etcd:
#     creation: 6h
#     retention: 24h
#     snapshot: true

# bastion_host:
#   address: ${aws_instance.rancher2-bastion.public_ip}
#   hostname_override: rancher2-bastion
#   ssh_key_path: ${var.rancher2-id-rsa-pub-path}
#   user: ec2-user

#   RANCHER_TEMPLATE
# }
