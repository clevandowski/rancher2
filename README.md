# Démarrer

```
make run
...
cyrille@dbf844fba3cb:~$
```

# Config AWS

Dans le container
```
~$ export AWS_PROFILE=clevandowski-ops-zenika
~$ aws iam get-user
{
    "User": {
        "UserName": "cyrille.levandowski.api", 
        "Path": "/", 
        "CreateDate": "2019-11-20T21:42:42Z", 
        "UserId": "********************", 
        "Arn": "arn:aws:iam::************:user/cyrille.levandowski.api"
    }
}
```

# Script basic

```
~/plans/1st_instance$ cat 1st_instance.tf
# Configure the AWS Provider
provider "aws" {
  shared_credentials_file = "/home/cyrille/.aws/credentials"
  profile = "clevandowski-ops-zenika"
  version = "~> 2.0"
}
```

## Initialisation plugin aws

```
~/plans/1st_instance$ terraform init

Initializing the backend...

Initializing provider plugins...
- Checking for available provider plugins...
- Downloading plugin for provider "aws" (hashicorp/aws) 2.39.0...

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

## Validate script

```
~/plans/1st_instance$ terraform validate
Success! The configuration is valid.
```

# Création instance AWS

## Script

```
~/plans/1st_instance$ cat 1st_instance.tf 
# Configure the AWS Provider
provider "aws" {
  shared_credentials_file = "/home/cyrille/.aws/credentials"
  profile = "clevandowski-ops-zenika"
  version = "~> 2.0"
  region = "eu-west-3"
}

resource "aws_instance" "clevando_instance" {
  ami           = "ami-087855b6c8b59a9e4"
  instance_type = "t2.micro"
  tags = {
    Name = "clevando_instance_test"
  }
}
```

## Plan

```
~/plans/1st_instance$ terraform plan -out 1st_instance.plan
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.


------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_instance.clevando_instance will be created
  + resource "aws_instance" "clevando_instance" {
      + ami                          = "ami-087855b6c8b59a9e4"
      + arn                          = (known after apply)
...
    }

Plan: 1 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------

This plan was saved to: 1st_instance.plan

To perform exactly these actions, run the following command to apply:
    terraform apply "1st_instance.plan"
```

## Apply

```
~/plans/1st_instance$ terraform apply -auto-approve "1st_instance.plan"
aws_instance.clevando_instance: Creating...
aws_instance.clevando_instance: Still creating... [10s elapsed]
aws_instance.clevando_instance: Still creating... [20s elapsed]
aws_instance.clevando_instance: Still creating... [30s elapsed]
aws_instance.clevando_instance: Still creating... [40s elapsed]
aws_instance.clevando_instance: Still creating... [50s elapsed]
aws_instance.clevando_instance: Still creating... [1m0s elapsed]
aws_instance.clevando_instance: Still creating... [1m10s elapsed]
aws_instance.clevando_instance: Still creating... [1m20s elapsed]
aws_instance.clevando_instance: Still creating... [1m30s elapsed]
aws_instance.clevando_instance: Still creating... [1m40s elapsed]
aws_instance.clevando_instance: Creation complete after 1m43s [id=i-0c0f954ba3e2ec324]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

The state of your infrastructure has been saved to the path
below. This state is required to modify and destroy your
infrastructure, so keep it safe. To inspect the complete state
use the `terraform show` command.

State path: terraform.tfstate
```

## Status

```
~/plans/1st_instance$ terraform show
# aws_instance.clevando_instance:
resource "aws_instance" "clevando_instance" {
    ami                          = "ami-087855b6c8b59a9e4"
    arn                          = "arn:aws:ec2:eu-west-3:301517625970:instance/i-0c0f954ba3e2ec324"
    associate_public_ip_address  = true
    availability_zone            = "eu-west-3b"
    cpu_core_count               = 1
    cpu_threads_per_core         = 1
    disable_api_termination      = false
    ebs_optimized                = false
    get_password_data            = false
    id                           = "i-0c0f954ba3e2ec324"
    instance_state               = "running"
    instance_type                = "t2.micro"
    ipv6_address_count           = 0
    ipv6_addresses               = []
    monitoring                   = false
    primary_network_interface_id = "eni-0feaf64d86a088ee4"
    private_dns                  = "ip-172-31-30-147.eu-west-3.compute.internal"
    private_ip                   = "172.31.30.147"
    public_dns                   = "ec2-35-180-68-212.eu-west-3.compute.amazonaws.com"
    public_ip                    = "35.180.68.212"
    security_groups              = [
        "default",
    ]
    source_dest_check            = true
    subnet_id                    = "subnet-d7907aac"
    tags                         = {
        "Name" = "clevando_instance_test"
    }
    tenancy                      = "default"
    volume_tags                  = {}
    vpc_security_group_ids       = [
        "sg-a56ddbcc",
    ]

    credit_specification {
        cpu_credits = "standard"
    }

    root_block_device {
        delete_on_termination = true
        encrypted             = false
        iops                  = 100
        volume_id             = "vol-0294c78efc448c686"
        volume_size           = 8
        volume_type           = "gp2"
    }
}
```

## Suppression

```
~/plans/1st_instance$ terraform destroy -auto-approve
aws_instance.clevando_instance: Refreshing state... [id=i-0c0f954ba3e2ec324]
aws_instance.clevando_instance: Destroying... [id=i-0c0f954ba3e2ec324]
aws_instance.clevando_instance: Still destroying... [id=i-0c0f954ba3e2ec324, 10s elapsed]
aws_instance.clevando_instance: Still destroying... [id=i-0c0f954ba3e2ec324, 20s elapsed]
aws_instance.clevando_instance: Destruction complete after 30s
```


# VM avec accès ssh

```
$ cat ~/.ssh/config
Host terraform-vm
  Hostname <ip vm>
  User ubuntu
  IdentityFile ~/.ssh/cyrillelevandowskiapi.pem
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

```
cd ~/plans/access_ssh
terraform validate
terraform init
terraform plan -out access_ssh.plan
terraform apply -auto-approve access_ssh.plan
terraform show
terraform destroy -auto-approve
```

# Multi VM avec accès ssh

```
$ cat ~/.ssh/config
Host terraform-mulivm-1
  Hostname <ip vm 1>
  User ubuntu
  IdentityFile ~/.ssh/cyrillelevandowskiapi.pem
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host terraform-mulivm-2
  Hostname <ip vm 2>
  User ubuntu
  IdentityFile ~/.ssh/cyrillelevandowskiapi.pem
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

```
cd ~/plans/multi_vms
terraform validate
terraform init
terraform plan -out multi_vms.plan
terraform apply -auto-approve multi_vms.plan
terraform show
terraform destroy -auto-approve
```

Vérification accès externe
```
ssh terraform-mulivm-1
ubuntu@ip-10-0-62-142:~$
```
==> Connecté !

# Rancher 2

```
cd ~/plans/rancher2
terraform init
terraform validate
terraform plan -out rancher2.plan
terraform apply -auto-approve rancher2.plan
terraform show
terraform destroy -auto-approve
```

```
inventory-template.sh
ansible-playbook playbook.yml
```

```
ansible all -m shell -a "hostname"
ansible all -m shell -a "docker version"
```