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
