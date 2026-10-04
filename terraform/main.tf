# ========================================
# VPC
# ========================================
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "petclinic-vpc"
  }
}

# ========================================
# Public Subnets
# ========================================
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "petclinic-public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "petclinic-public-subnet-2"
  }
}

# ========================================
# Private Subnets
# ========================================
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "petclinic-private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "petclinic-private-subnet-2"
  }
}

# ========================================
# Internet Gateway
# ========================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "petclinic-igw"
  }
}

# ========================================
# Public Route Table
# ========================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "petclinic-public-route-table"
  }
}

# ========================================
# Public Route
# ========================================
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# ========================================
# Route Table Associations
# ========================================
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ========================================
# Elastic IPs for NAT Gateways
# ========================================

resource "aws_eip" "nat_1" {
  domain = "vpc"

  tags = {
    Name = "petclinic-nat-eip-1"
  }
}

resource "aws_eip" "nat_2" {
  domain = "vpc"

  tags = {
    Name = "petclinic-nat-eip-2"
  }
}

# ========================================
# NAT Gateways
# ========================================
resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "petclinic-nat-gateway-1"
  }
}

resource "aws_nat_gateway" "nat_2" {
  allocation_id = aws_eip.nat_2.id
  subnet_id     = aws_subnet.public_2.id

  tags = {
    Name = "petclinic-nat-gateway-2"
  }
}

# ========================================
# Private Route Tables
# ========================================
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "petclinic-private-route-table-1"
  }
}

resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "petclinic-private-route-table-2"
  }
}

# ========================================
# Private Routes
# ========================================
resource "aws_route" "private_1_internet_access" {
  route_table_id         = aws_route_table.private_1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_1.id
}

resource "aws_route" "private_2_internet_access" {
  route_table_id         = aws_route_table.private_2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_2.id
}

# ========================================
# Private Route Table Associations
# ========================================
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_2.id
}

# ========================================
# EC2 IAM Role for Systems Manager
# ========================================
resource "aws_iam_role" "ec2_ssm_role" {
  name = "petclinic-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# ========================================
# Attach SSM Permissions to EC2 IAM Role
# ========================================
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ========================================
# EC2 Instance Profile
# ========================================
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "petclinic-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# ========================================
# EC2 Security Group
# ========================================
resource "aws_security_group" "ec2_ssm_sg" {
  name        = "petclinic-ec2-ssm-sg"
  description = "Security group for private EC2 managed through SSM"
  vpc_id      = aws_vpc.main.id

}

resource "aws_vpc_security_group_egress_rule" "ec2_ssm_https" {
  security_group_id = aws_security_group.ec2_ssm_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  description = "Allow outbound HTTPS for SSM connectivity"
}

# ========================================
# EC2 AMI
# ========================================
data "aws_ami" "rhel9" {
  most_recent = true
  owners      = ["309956199498"]

  filter {
    name   = "name"
    values = ["RHEL-9.8.0_HVM-*-x86_64-0-Hourly2-GP3"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ========================================
# Private EC2 Instance
# ========================================
resource "aws_instance" "ssm_test" {
  ami                         = data.aws_ami.rhel9.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.private_1.id
  associate_public_ip_address = false
  vpc_security_group_ids = [
    aws_security_group.ec2_ssm_sg.id
  ]
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  user_data = <<-EOF
  #!/bin/bash

  dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm

  systemctl enable amazon-ssm-agent
  systemctl start amazon-ssm-agent
EOF
  depends_on = [
    aws_route.private_1_internet_access
  ]

  tags = {
    Name = "petclinic-ssm-test"
  }
}
