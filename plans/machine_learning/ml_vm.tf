variable "aws_profile" {
  type = string
  description = "your aws profile here from ~/.aws/credentials"
}

variable "aws_region" {
  type = string
  default = "eu-west-3"
}

variable "authorized_ip" {
  type = string
  default = "0.0.0.0/0"
}

data "aws_ami" "latest_ubuntu_desktop" {
  owners = ["099720109477"] # Canonical
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
  # filter {
  #   name = "Public"
  #   values = ["true"]
  # }
}

# Configure the AWS Provider
provider "aws" {
  profile = var.aws_profile
  version = "~> 2.0"
  region = var.aws_region
}

# https://medium.com/@hmalgewatta/setting-up-an-aws-ec2-instance-with-ssh-access-using-terraform-c336c812322f
resource "aws_key_pair" "ml_kp" {
  key_name  = "ml_kp"
  public_key = file("~/.ssh/id_rsa.pub")
}

# Create a VPC
resource "aws_vpc" "ml_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ml_vpc"
  }
}

# Create a Subnet
resource "aws_subnet" "ml_subnet" {
  cidr_block = cidrsubnet(aws_vpc.ml_vpc.cidr_block, 3, 1)
  # cidr_block = "10.0.0.0/24"
  vpc_id = aws_vpc.ml_vpc.id
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "ml_subnet"
  }
}


resource "aws_internet_gateway" "ml_igw" {
  vpc_id = aws_vpc.ml_vpc.id
  tags = {
    Name = "ml_igw"
  }
}

resource "aws_route_table" "ml_rt" {
  vpc_id = aws_vpc.ml_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ml_igw.id
  }
  tags = {
    Name = "ml_rt"
  }
}

resource "aws_route_table_association" "ml_rta" {
  subnet_id = aws_subnet.ml_subnet.id
  route_table_id = aws_route_table.ml_rt.id
}

# Create a Security Group
resource "aws_security_group" "ml_sg" {
  name = "ml_sg"
  vpc_id = aws_vpc.ml_vpc.id
  ingress {
    cidr_blocks = [var.authorized_ip]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ml_sg"
  }
}

# ec2 instance
resource "aws_instance" "ml_instance" {
  ami = data.aws_ami.latest_ubuntu_desktop.id
  instance_type = "g4dn.2xlarge"
  key_name = aws_key_pair.ml_kp.key_name
  security_groups = [aws_security_group.ml_sg.id]
  subnet_id = aws_subnet.ml_subnet.id
  associate_public_ip_address = true
  tags = {
    Name = "ml_instance"
  }
}
