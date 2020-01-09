# Configure the AWS Provider
provider "aws" {
  shared_credentials_file = "/home/cyrille/.aws/credentials"
  profile = "clevandowski-ops-zenika"
  version = "~> 2.0"
  region = "eu-central-1"
}

# https://medium.com/@hmalgewatta/setting-up-an-aws-ec2-instance-with-ssh-access-using-terraform-c336c812322f

# Create a VPC
resource "aws_vpc" "clevando_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "clevando_vpc"
  }
}

# Create a Subnet
resource "aws_subnet" "clevando_subnet" {
  cidr_block = "${cidrsubnet(aws_vpc.clevando_vpc.cidr_block, 3, 1)}"
  vpc_id = "${aws_vpc.clevando_vpc.id}"
  availability_zone = "eu-central-1a"
  tags = {
    Name = "clevando_subnet"
  }
}

# Create a Security Group
resource "aws_security_group" "clevando_sg" {
  name = "clevando_sg"
  vpc_id = "${aws_vpc.clevando_vpc.id}"
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
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
    Name = "clevando_sg"
  }
}

# ec2 instance
resource "aws_instance" "clevando_instance" {
  ami = "ami-0cc0a36f626a4fdf5"
  count = 2
  instance_type = "t2.micro"
  key_name = "cyrille.levandowski.api"
  security_groups = ["${aws_security_group.clevando_sg.id}"]
  subnet_id = "${aws_subnet.clevando_subnet.id}"
  associate_public_ip_address = true
  tags = {
    Name = "clevando_instance_${count.index + 1}"
  }
}

resource "aws_internet_gateway" "clevando_gw" {
  vpc_id = "${aws_vpc.clevando_vpc.id}"
  tags = {
    Name = "clevando_gw"
  }
}

resource "aws_route_table" "clevando_rt" {
  vpc_id = "${aws_vpc.clevando_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.clevando_gw.id}"
  }
  tags = {
    Name = "clevando_rt"
  }
}

resource "aws_route_table_association" "clevando_rta" {
  subnet_id = "${aws_subnet.clevando_subnet.id}"
  route_table_id = "${aws_route_table.clevando_rt.id}"
}

resource "aws_main_route_table_association" "clevando_rta" {
  vpc_id = "${aws_vpc.clevando_vpc.id}"
  route_table_id = "${aws_route_table.clevando_rt.id}"
}