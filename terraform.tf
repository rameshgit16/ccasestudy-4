# 1. Provider
provider "aws" {
  region = "ap-south-1" # You can change the region as per your requirement
}

# 2. Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# 3. Create Subnets in different Availability Zones
resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
}

resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
}

resource "aws_subnet" "subnet3" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "ap-south-1c"
}

# 4. Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# 5. Create a Route Table and associate with the Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "subnet1_association" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "subnet2_association" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "subnet3_association" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.public.id
}

# 6. Security Group allowing SSH and HTTP
resource "aws_security_group" "allow_ssh_http" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 7. Launch EC2 Instances
resource "aws_instance" "web1" {
  ami           = "ami-0888ba30fd446b771" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet1.id
  security_groups = [aws_security_group.allow_ssh_http.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user
              EOF

  tags = {
    Name = "EC2_Instance_1"
  }
}

resource "aws_instance" "web2" {
  ami           = "ami-0888ba30fd446b771"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet2.id
  security_groups = [aws_security_group.allow_ssh_http.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user
              EOF

  tags = {
    Name = "EC2_Instance_2"
  }
}

resource "aws_instance" "web3" {
  ami           = "ami-0888ba30fd446b771"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet3.id
  security_groups = [aws_security_group.allow_ssh_http.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user
              EOF

  tags = {
    Name = "EC2_Instance_3"
  }
}

# 8. Create S3 Bucket for Shared Storage
resource "aws_s3_bucket" "shared_bucket" {
  bucket = "my-shared-bucket-terraform"

  tags = {
    Name        = "Shared_S3_Bucket"
    Environment = "Dev"
  }
}

# 9. IAM Role for EC2 to Access S3
resource "aws_iam_role" "ec2_s3_access" {
  name = "ec2_s3_access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_s3_policy" {
  name   = "ec2_s3_policy"
  role   = aws_iam_role.ec2_s3_access.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Effect   = "Allow",
        Resource = [
          aws_s3_bucket.shared_bucket.arn,
          "${aws_s3_bucket.shared_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_s3_access.name
}

# 10. Output
output "s3_bucket_name" {
  value = aws_s3_bucket.shared_bucket.bucket
}
