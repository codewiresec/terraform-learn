terraform {
  required_version = ">=0.12"
  backend "s3" {
    bucket = "shigidi"
    key    = "myapp/state.tfstate"
    region = "us-east-1"
  }

}

provider "aws" {
  region = "us-east-1"
}
#----------------------------------------------------VARIABLES

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "public_key_location" {}
variable "private_key_location" {}


#----------------------------------------------------SYNTAX VPC
resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    "Name" = "${var.env_prefix}-vpc"
  }
}
#----------------------------------------------------SYNTAX SUBNET
resource "aws_subnet" "myapp-subnet-1" {
  vpc_id            = aws_vpc.myapp-vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name = "${var.env_prefix}-subnet-1"
  }
}
#----------------------------------------------------SYNTAX RTB

resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.myapp-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }

  tags = {
    Name : "${var.env_prefix}-rtb"
  }
}
#----------------------------------------------------SYNTAX IGW

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    Name : "${var.env_prefix}-igw"
  }
}

#----------------------------------------------------SYNTAX SUB-RTB ASSO

resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id      = aws_subnet.myapp-subnet-1.id
  route_table_id = aws_route_table.myapp-route-table.id
}

#----------------------------------------------------SYNTAX SG

resource "aws_security_group" "myapp-sg" {
  name   = "myapp-sg"
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name : "${var.env_prefix}-myapp-sg"
  }
}

#----------------------------------------------------SYNTAX AWS IMAGE

data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#----------------------------------------------------SYNTAX EC2 W/ MANUAL KEY

# resource "aws_instance" "myapp-server" {
#   ami                         = data.aws_ami.latest-amazon-linux-image.id
#   instance_type               = var.instance_type
#   subnet_id                   = aws_subnet.myapp-subnet-1.id
#   vpc_security_group_ids      = [aws_security_group.myapp-sg.id]
#   availability_zone           = var.avail_zone
#   associate_public_ip_address = true
#   key_name                    = "server-key-pair"
#   tags = {
#     "Name" = "${var.env_prefix}-server"
#   }
# }

#----------------------------------------------------SYNTAX EC2 W/ AUTO KEY

resource "aws_key_pair" "ssh-key" {
  key_name   = "shigidi"
  public_key = file(var.public_key_location)
}

resource "aws_instance" "myapp-server" {
  ami                         = data.aws_ami.latest-amazon-linux-image.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids      = [aws_security_group.myapp-sg.id]
  availability_zone           = var.avail_zone
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ssh-key.key_name

  tags = {
    "Name" = "${var.env_prefix}-server"
  }
  #----------------------------------------------------SYNTAX CONFIGS NGINX ON EC2
  user_data = file("entry-script.sh")
}

#----------------------------------------------------SYNTAX OUTPUTS
output "ec2_public_ip" {
  value = aws_instance.myapp-server.public_ip
}
output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

# #----------------------------------------------------SYNTAX PROVISIONER CONFIG EC2
# connection {
#   type        = "ssh"
#   host        = self.public_ip
#   user        = "ec2-user"
#   private_key = file(var.private_key_location)
# }
