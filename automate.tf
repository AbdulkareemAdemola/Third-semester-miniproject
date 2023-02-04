terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  
  region  = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

# Create VPC
resource "aws_vpc" "miniproject_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "miniproject_vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "miniproject_internet_gateway" {
  vpc_id = aws_vpc.miniproject_vpc.id
  tags = {
    Name = "miniproject_internet_gateway"
  }
}

#create route table
resource "aws_route_table" "miniproject-route-table-public" {
  vpc_id = aws_vpc.miniproject_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.miniproject_internet_gateway.id
  }
  tags = {
    Name = "miniproject-route-table-public"
  }
}

resource "aws_route_table_association" "miniproject-public-subnet1-association" {
  subnet_id      = aws_subnet.miniproject-public-subnet1.id
  route_table_id = aws_route_table.miniproject-route-table-public.id
}
# Associate public subnet 2 with public route table
resource "aws_route_table_association" "miniproject-public-subnet2-association" {
  subnet_id      = aws_subnet.miniproject-public-subnet2.id
  route_table_id = aws_route_table.miniproject-route-table-public.id
}

# create public subnet-1
resource "aws_subnet" "miniproject-public-subnet1" {
  vpc_id                  = aws_vpc.miniproject_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "miniproject-public-subnet1"
  }
}
# Create Public Subnet-2
resource "aws_subnet" "miniproject-public-subnet2" {
  vpc_id                  = aws_vpc.miniproject_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  tags = {
    Name = "miniproject-public-subnet2"
  }
}

resource "aws_network_acl" "miniproject-network_acl" {
vpc_id     = aws_vpc.miniproject_vpc.id
subnet_ids = [aws_subnet.miniproject-public-subnet1.id, aws_subnet.miniproject-public-subnet2.id]


 ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}

# security group for load balancer
  resource "aws_security_group" "miniproject-load_balancer_sg" {
  name        = "miniproject-load-balancer-sg"
  description = "Security group for the load balancer"
  vpc_id      = aws_vpc.miniproject_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group to allow port 22, 80 and 443 for ec2 instances
resource "aws_security_group" "miniproject-security-grp-rule" {
  name        = "allow_ssh_http_https"
  description = "Allow SSH, HTTP and HTTPS inbound traffic for private instances"
  vpc_id      = aws_vpc.miniproject_vpc.id
 ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.miniproject-load_balancer_sg.id]
  }

 ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.miniproject-load_balancer_sg.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
   
  }
  tags = {
    Name = "miniproject-security-grp-rule"
  }
}

  
# creating instance 1
resource "aws_instance" "NUMBER1" {
  ami             = "ami-00874d747dde814fa"
  instance_type   = "t2.micro"
  key_name        = "holiday-vpc"
  security_groups = [aws_security_group.miniproject-security-grp-rule.id]
  subnet_id       = aws_subnet.miniproject-public-subnet1.id
  availability_zone = "us-east-1a"
  tags = {
    Name   = "NUMBER1"
    source = "terraform"
  }
}

# creating instance 2
 resource "aws_instance" "NUMBER2" {
  ami             = "ami-00874d747dde814fa"
  instance_type   = "t2.micro"
  key_name        = "holiday-vpc"
  security_groups = [aws_security_group.miniproject-security-grp-rule.id]
  subnet_id       = aws_subnet.miniproject-public-subnet2.id
  availability_zone = "us-east-1b"
  tags = {
    Name   = "NUMBER2"
    source = "terraform"
  }
}
# creating instance 3
resource "aws_instance" "NUMBER3" {
  ami             = "ami-00874d747dde814fa"
  instance_type   = "t2.micro"
  key_name        = "holiday-vpc"
  security_groups = [aws_security_group.miniproject-security-grp-rule.id]
  subnet_id       = aws_subnet.miniproject-public-subnet1.id
  availability_zone = "us-east-1a"
  tags = {
    Name   = "NUMBER3"
    source = "terraform"
  }
}

# Create a file to store the IP addresses of the instances
resource "local_file" "Ip_address" {
  filename ="/vagrant/terra/host-inventory"
  content  = <<EOT
${aws_instance.NUMBER1.public_ip}
${aws_instance.NUMBER2.public_ip}
${aws_instance.NUMBER3.public_ip}
  EOT
}

# Create an Application Load Balancer
resource "aws_lb" "miniproject-load-balancer" {
  name               = "miniproject-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.miniproject-load_balancer_sg.id]
  subnets            = [aws_subnet.miniproject-public-subnet1.id, aws_subnet.miniproject-public-subnet2.id]
  enable_cross_zone_load_balancing = true
  enable_deletion_protection = false
  depends_on                 = [aws_instance.NUMBER1, aws_instance.NUMBER2, aws_instance.NUMBER3]
}

# Create the target group
resource "aws_lb_target_group" "miniproject-target-group" {
  name     = "miniproject-target-group"
  target_type = "instance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.miniproject_vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Create the listener
resource "aws_lb_listener" "miniproject-listener" {
  load_balancer_arn = aws_lb.miniproject-load-balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.miniproject-target-group.arn
  }
}
# Create the listener rule
resource "aws_lb_listener_rule" "miniproject-listener-rule" {
  listener_arn = aws_lb_listener.miniproject-listener.arn
  priority     = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.miniproject-target-group.arn
  }
  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

# Attach the target group to the load balancer
resource "aws_lb_target_group_attachment" "miniproject-target-group-attachment1" {
  target_group_arn = aws_lb_target_group.miniproject-target-group.arn
  target_id        = aws_instance.NUMBER1.id
  port             = 80
}
 
resource "aws_lb_target_group_attachment" "miniproject-target-group-attachment2" {
  target_group_arn = aws_lb_target_group.miniproject-target-group.arn
  target_id        = aws_instance.NUMBER2.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "miniproject-target-group-attachment3" {
  target_group_arn = aws_lb_target_group.miniproject-target-group.arn
  target_id        = aws_instance.NUMBER3.id
  port             = 80 
  
  }

# get hosted zone details
resource "aws_route53_zone" "hosted_zone" {
  name = var.domain_name
  tags = {
    Environment = "dev"
  }
}
# create a record set in route 53
# terraform aws route 53 record
resource "aws_route53_record" "site_domain" {
  zone_id = aws_route53_zone.hosted_zone.zone_id
  name    = "terraform-test.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_lb.miniproject-load-balancer.dns_name
    zone_id                = aws_lb.miniproject-load-balancer.zone_id
    evaluate_target_health = true
  }
}
