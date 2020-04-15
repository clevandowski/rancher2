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

