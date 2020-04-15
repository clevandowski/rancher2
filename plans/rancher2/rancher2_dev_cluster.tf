##########################################
# Private Zone rancher2-x-private-subnet #
##########################################

# variable "rancher2-dev-master-lb-dns" {
#   type = string
#   description = "Enregistrement DNS associée à Rancher sur Route53 rancher.mydomain.com"
#   default = "master.dev.cyrille.aws.zenika.com"
# }

# Zone a
resource "aws_subnet" "rancher2-private-dev-a-subnet" {
  # Input: "10.0.0.0/16" => Output: "10.0.7.0/24"
  cidr_block = cidrsubnet(aws_vpc.rancher2-vpc.cidr_block, 8, 7)
  vpc_id = aws_vpc.rancher2-vpc.id
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "rancher2-private-dev-a-subnet"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}
resource "aws_route_table_association" "rancher2-private-dev-a-subnet-to-ngw-rta" {
  route_table_id = aws_route_table.rancher2-private-a-to-ngw-rt.id
  subnet_id = aws_subnet.rancher2-private-dev-a-subnet.id
}

# Zone b
resource "aws_subnet" "rancher2-private-dev-b-subnet" {
  # Input: "10.0.0.0/16" => Output: "10.0.8.0/24"
  cidr_block = cidrsubnet(aws_vpc.rancher2-vpc.cidr_block, 8, 8)
  vpc_id = aws_vpc.rancher2-vpc.id
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "rancher2-private-dev-b-subnet"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}
resource "aws_route_table_association" "rancher2-private-dev-b-subnet-to-ngw-rta" {
  route_table_id = aws_route_table.rancher2-private-b-to-ngw-rt.id
  subnet_id = aws_subnet.rancher2-private-dev-b-subnet.id
}

# Zone c
resource "aws_subnet" "rancher2-private-dev-c-subnet" {
  # Input: "10.0.0.0/16" => Output: "10.0.9.0/24"
  cidr_block = cidrsubnet(aws_vpc.rancher2-vpc.cidr_block, 8, 9)
  vpc_id = aws_vpc.rancher2-vpc.id
  availability_zone = "${var.aws_region}c"
  tags = {
    Name = "rancher2-private-dev-c-subnet"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
  }
}
resource "aws_route_table_association" "rancher2-private-dev-c-subnet-to-ngw-rta" {
  route_table_id = aws_route_table.rancher2-private-c-to-ngw-rt.id
  subnet_id = aws_subnet.rancher2-private-dev-c-subnet.id
}

# resource "aws_lb_target_group" "rancher2-dev-master-tcp-80-tg" {
#   name = "rancher2-dev-master-tcp-80-tg"
#   port = 80
#   protocol = "TCP"
#   vpc_id = aws_vpc.rancher2-vpc.id
#   target_type = "instance"
#   health_check {
#     protocol = "HTTP"
#     path = "/healthz"
#     port = "traffic-port"
#     healthy_threshold = 3
#     unhealthy_threshold = 3
#     timeout = 6
#     interval = 10
#     matcher = "200-399"
#   }
# }

# resource "aws_lb_target_group" "rancher2-dev-master-tcp-443-tg" {
#   name = "rancher2-dev-master-tcp-443-tg"
#   port = 443
#   protocol = "TCP"
#   vpc_id = aws_vpc.rancher2-vpc.id
#   target_type = "instance"
#   health_check {
#     protocol = "HTTP"
#     path = "/healthz"
#     port = "traffic-port"
#     healthy_threshold = 3
#     unhealthy_threshold = 3
#     timeout = 6
#     interval = 10
#     matcher = "200-399"
#   }
# }

# resource "aws_lb" "rancher2-dev-master-nlb" {
#   name = "rancher2-dev-master-nlb"
#   load_balancer_type = "network"
#   internal = false
#   # subnets = [aws_subnet.rancher2-bastion-subnet.id]
#   subnets = [aws_subnet.rancher2-a-public-subnet.id,aws_subnet.rancher2-b-public-subnet.id,aws_subnet.rancher2-c-public-subnet.id]
#   enable_deletion_protection = false
#   enable_cross_zone_load_balancing = true
#   tags = {
#     Name = "rancher"
#     Zone = "Public"
#   }
#   depends_on = [
#     aws_route_table_association.rancher2-a-public-subnet-to-igw-rta,
#     aws_route_table_association.rancher2-b-public-subnet-to-igw-rta,
#     aws_route_table_association.rancher2-c-public-subnet-to-igw-rta
#   ]
# }
# resource "aws_lb_listener" "rancher2-dev-master-tcp-443-nlb-listener" {
#   load_balancer_arn = aws_lb.rancher2-dev-master-nlb.arn
#   protocol = "TCP"
#   port = "443"
#   default_action {
#     type = "forward"
#     target_group_arn = aws_lb_target_group.rancher2-dev-master-tcp-443-tg.arn
#   }
# }
# resource "aws_lb_listener" "rancher2-dev-master-tcp-80-nlb-listener" {
#   load_balancer_arn = aws_lb.rancher2-dev-master-nlb.arn
#   protocol = "TCP"
#   port = "80"
#   default_action {
#     type = "forward"
#     target_group_arn = aws_lb_target_group.rancher2-dev-master-tcp-80-tg.arn
#   }
# }
# resource "aws_route53_record" "rancher2-dev-master-lb-dns" {
#   count = var.rancher2-hosted-zone-id != "" ? 1 : 0
#   zone_id = var.rancher2-hosted-zone-id
#   name = var.rancher2-dev-master-lb-dns
#   type = "A"
#   alias {
#     name = aws_lb.rancher2-dev-master-nlb.dns_name
#     zone_id = aws_lb.rancher2-dev-master-nlb.zone_id
#     evaluate_target_health = true
#   }
# }

# ec2 instances
resource "aws_instance" "rancher2-dev-a-master" {
  ami = data.aws_ami.latest-ubuntu.id
  instance_type = var.aws_instance_type_master
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = aws_key_pair.rancher2-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-etcd-sg.id,aws_security_group.rancher2-controlplane-sg.id]
  subnet_id = aws_subnet.rancher2-private-dev-a-subnet.id
  root_block_device {
    volume_size = 16
  }
  tags = {
    Name = "rancher2-dev-a-master"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
    role_rke = true
    role_etcd = true
    role_controlplane = true
    role_worker = false
    cluster = "dev"
  }
}
# resource "aws_lb_target_group_attachment" "rancher2-dev-a-master-tcp-80-tga" {
#   target_group_arn = aws_lb_target_group.rancher2-dev-master-tcp-80-tg.arn
#   target_id = aws_instance.rancher2-dev-a-master.id
#   port = 80
# }
# resource "aws_lb_target_group_attachment" "rancher2-dev-a-master-tcp-443-tga" {
#   target_group_arn = aws_lb_target_group.rancher2-dev-master-tcp-443-tg.arn
#   target_id = aws_instance.rancher2-dev-a-master.id
#   port = 443
# }

resource "aws_instance" "rancher2-dev-b-master" {
  ami = data.aws_ami.latest-ubuntu.id
  instance_type = var.aws_instance_type_master
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = aws_key_pair.rancher2-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-etcd-sg.id,aws_security_group.rancher2-controlplane-sg.id]
  subnet_id = aws_subnet.rancher2-private-dev-b-subnet.id
  root_block_device {
    volume_size = 16
  }
  tags = {
    Name = "rancher2-dev-b-master"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
    role_rke = true
    role_etcd = true
    role_controlplane = true
    role_worker = false
    cluster = "dev"
  }
}
# resource "aws_lb_target_group_attachment" "rancher2-dev-b-master-tcp-80-tga" {
#   target_group_arn = aws_lb_target_group.rancher2-dev-master-tcp-80-tg.arn
#   target_id = aws_instance.rancher2-dev-b-master.id
#   port = 80
# }
# resource "aws_lb_target_group_attachment" "rancher2-dev-b-master-tcp-443-tga" {
#   target_group_arn = aws_lb_target_group.rancher2-dev-master-tcp-443-tg.arn
#   target_id = aws_instance.rancher2-dev-b-master.id
#   port = 443
# }

resource "aws_instance" "rancher2-dev-c-master" {
  ami = data.aws_ami.latest-ubuntu.id
  instance_type = var.aws_instance_type_master
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = aws_key_pair.rancher2-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-etcd-sg.id,aws_security_group.rancher2-controlplane-sg.id]
  subnet_id = aws_subnet.rancher2-private-dev-c-subnet.id
  root_block_device {
    volume_size = 16
  }
  tags = {
    Name = "rancher2-dev-c-master"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
    role_rke = true
    role_etcd = true
    role_controlplane = true
    role_worker = false
    cluster = "dev"
  }
}
# resource "aws_lb_target_group_attachment" "rancher2-dev-c-master-tcp-80-tga" {
#   target_group_arn = aws_lb_target_group.rancher2-dev-master-tcp-80-tg.arn
#   target_id = aws_instance.rancher2-dev-c-master.id
#   port = 80
# }
# resource "aws_lb_target_group_attachment" "rancher2-dev-c-master-tcp-443-tga" {
#   target_group_arn = aws_lb_target_group.rancher2-dev-master-tcp-443-tg.arn
#   target_id = aws_instance.rancher2-dev-c-master.id
#   port = 443
# }

resource "aws_instance" "rancher2-dev-a-worker" {
  ami = data.aws_ami.latest-ubuntu.id
  instance_type = var.aws_instance_type_worker
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = aws_key_pair.rancher2-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-worker-sg.id]
  subnet_id = aws_subnet.rancher2-private-dev-a-subnet.id
  root_block_device {
    volume_size = 32
  }
  tags = {
    Name = "rancher2-dev-a-worker"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
    role_rke = true
    role_etcd = false
    role_controlplane = false
    role_worker = true
    cluster = "dev"
  }
}

resource "aws_instance" "rancher2-dev-b-worker" {
  ami = data.aws_ami.latest-ubuntu.id
  instance_type = var.aws_instance_type_worker
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = aws_key_pair.rancher2-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-worker-sg.id]
  subnet_id = aws_subnet.rancher2-private-dev-b-subnet.id
  root_block_device {
    volume_size = 32
  }
  tags = {
    Name = "rancher2-dev-b-worker"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
    role_rke = true
    role_etcd = false
    role_controlplane = false
    role_worker = true
    cluster = "dev"
  }
}

resource "aws_instance" "rancher2-dev-c-worker" {
  ami = data.aws_ami.latest-ubuntu.id
  instance_type = var.aws_instance_type_worker
  iam_instance_profile = aws_iam_instance_profile.rancher2-instance-profile.name
  key_name = aws_key_pair.rancher2-key-pair.key_name
  vpc_security_group_ids = [aws_security_group.rancher2-sg.id,aws_security_group.rancher2-worker-sg.id]
  subnet_id = aws_subnet.rancher2-private-dev-c-subnet.id
  root_block_device {
    volume_size = 32
  }
  tags = {
    Name = "rancher2-dev-c-worker"
    Zone = "Private"
    "kubernetes.io/cluster/rancher-master" = "owned"
    role_rke = true
    role_etcd = false
    role_controlplane = false
    role_worker = true
    cluster = "dev"
  }
}

# output "inventory-dev" {
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
#         rancher2-dev-a-master:
#           ansible_host: ${aws_instance.rancher2-dev-a-master.private_ip}
#           private_dns: ${aws_instance.rancher2-dev-a-master.private_dns}
#           private_ip: ${aws_instance.rancher2-dev-a-master.private_ip}
#         rancher2-dev-b-master:
#           ansible_host: ${aws_instance.rancher2-dev-b-master.private_ip}
#           private_dns: ${aws_instance.rancher2-dev-b-master.private_dns}
#           private_ip: ${aws_instance.rancher2-dev-b-master.private_ip}
#         rancher2-dev-c-master:
#           ansible_host: ${aws_instance.rancher2-dev-c-master.private_ip}
#           private_dns: ${aws_instance.rancher2-dev-c-master.private_dns}
#           private_ip: ${aws_instance.rancher2-dev-c-master.private_ip}
#         rancher2-dev-a-worker:
#           ansible_host: ${aws_instance.rancher2-dev-a-worker.private_ip}
#           private_dns: ${aws_instance.rancher2-dev-a-worker.private_dns}
#           private_ip: ${aws_instance.rancher2-dev-a-worker.private_ip}
#         rancher2-dev-b-worker:
#           ansible_host: ${aws_instance.rancher2-dev-b-worker.private_ip}
#           private_dns: ${aws_instance.rancher2-dev-b-worker.private_dns}
#           private_ip: ${aws_instance.rancher2-dev-b-worker.private_ip}
#         rancher2-dev-c-worker:
#           ansible_host: ${aws_instance.rancher2-dev-c-worker.private_ip}
#           private_dns: ${aws_instance.rancher2-dev-c-worker.private_dns}
#           private_ip: ${aws_instance.rancher2-dev-c-worker.private_ip}
#       vars:
#         ansible_user: ubuntu
#   vars:
#     ansible_connection: ssh
#     ansible_port: 22

# INVENTORY
# }

# output "rancher-template-dev" {
#   value = <<RANCHER_TEMPLATE
# cloud_provider:
#   _comment: cf https://github.com/rancher/rancher/issues/24329
#   awsCloudProvider:
#     global:
#       disable-security-group-ingress: false
#       disable-strict-zone-check: false
#   name: aws
# nodes:
# - address: ${aws_instance.rancher2-dev-a-master.private_ip}
#   hostname_override: rancher2-dev-a-master
#   role:
#   - controlplane
#   - etcd
#   - worker
#   ssh_key_path: ${var.rancher2-id-rsa-pub-path}
#   user: ubuntu
# - address: ${aws_instance.rancher2-dev-b-master.private_ip}
#   hostname_override: rancher2-dev-b-master
#   role:
#   - controlplane
#   - etcd
#   - worker
#   ssh_key_path: ~/.ssh/aws
#   ssh_key_path: ${var.rancher2-id-rsa-pub-path}
# - address: ${aws_instance.rancher2-dev-c-master.private_ip}
#   hostname_override: rancher2-dev-c-master
#   role:
#   - controlplane
#   - etcd
#   - worker
#   ssh_key_path: ${var.rancher2-id-rsa-pub-path}
#   user: ubuntu
# - address: ${aws_instance.rancher2-dev-a-worker.private_ip}
#   hostname_override: rancher2-dev-a-worker
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
# - address: ${aws_instance.rancher2-dev-b-worker.private_ip}
#   hostname_override: rancher2-dev-b-worker
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
# - address: ${aws_instance.rancher2-dev-c-worker.private_ip}
#   hostname_override: rancher2-dev-c-worker
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
