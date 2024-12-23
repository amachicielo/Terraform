# Configure the AWS provider
provider "aws" {
  region = "us-west-2"
}

# Create a VPC for the deployment
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "blue-green-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# Create security group for the instances
resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "Security group for application instances"
  vpc_id      = module.vpc.vpc_id

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

# Create launch template for blue environment
resource "aws_launch_template" "blue" {
  name_prefix   = "blue-"
  image_id      = "ami-0c55b159cbfafe1f0"  # Replace with your AMI ID
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "blue-instance"
    }
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "Hello from Blue Environment" > index.html
              nohup python -m SimpleHTTPServer 80 &
              EOF
  )
}

# Create launch template for green environment
resource "aws_launch_template" "green" {
  name_prefix   = "green-"
  image_id      = "ami-0c55b159cbfafe1f0"  # Replace with your AMI ID
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "green-instance"
    }
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "Hello from Green Environment" > index.html
              nohup python -m SimpleHTTPServer 80 &
              EOF
  )
}

# Create Auto Scaling group for blue environment
resource "aws_autoscaling_group" "blue" {
  name                = "blue-asg"
  vpc_zone_identifier = module.vpc.private_subnets
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1

  launch_template {
    id      = aws_launch_template.blue.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.blue.arn]
}

# Create Auto Scaling group for green environment
resource "aws_autoscaling_group" "green" {
  name                = "green-asg"
  vpc_zone_identifier = module.vpc.private_subnets
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1

  launch_template {
    id      = aws_launch_template.green.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.green.arn]
}

# Create Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets            = module.vpc.public_subnets
}

# Create target group for blue environment
resource "aws_lb_target_group" "blue" {
  name     = "blue-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

# Create target group for green environment
resource "aws_lb_target_group" "green" {
  name     = "green-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

# Create listener rule for blue-green deployment
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}

# Output the load balancer DNS name
output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.app_lb.dns_name
}

