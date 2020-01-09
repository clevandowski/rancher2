# Configure the AWS Provider
provider "aws" {
  shared_credentials_file = "/home/cyrille/.aws/credentials"
  profile = "clevandowski-ops-zenika"
  version = "~> 2.0"
  region = "eu-west-3"
}

# Create a VPC
# resource "clevandowski_aws_vpc" "example" {
#   cidr_block = "10.0.0.0/16"
# }

resource "aws_instance" "clevando_instance" {
  ami           = "ami-087855b6c8b59a9e4"
  instance_type = "t2.micro"
#  region = "eu-west-3"
  tags = {
    Name = "clevando_instance_test"
  }
}
