resource "aws_iam_role" "rancher2-role" {
  name = "rancher2-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "rancher2-instance-profile" {
  name = "rancher2-instance-profile"
  role = aws_iam_role.rancher2-role.name
}

resource "aws_iam_role_policy" "rancher2-role-policy" {
  name = "rancher2-role-policy"
  role = aws_iam_role.rancher2-role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": "elasticloadbalancing:*",
        "Resource": "*"
    }
  ]
}
EOF
}
