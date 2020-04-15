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

variable "rancher2-hosted-zone-id" {
  type = string
  description = "A injecter en fonction d'une hosted zone existante"
  default = ""
}

variable "rancher2-id-rsa-pub-path" {
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

# https://medium.com/@hmalgewatta/setting-up-an-aws-ec2-instance-with-ssh-access-using-terraform-c336c812322f
resource "aws_key_pair" "rancher2-key-pair" {
  key_name   = "rancher2-key-pair"
  public_key = file(var.rancher2-id-rsa-pub-path)
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
