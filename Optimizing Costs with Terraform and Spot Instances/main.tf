provider "aws" {
  region = "us-west-2"
}

resource "aws_launch_template" "example" {
  name_prefix   = "example-template"
  image_id      = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (adjust as needed)
  instance_type = "t3.micro"

  # Add other configuration as needed (security groups, IAM instance profile, etc.)
}

resource "aws_autoscaling_group" "example" {
  name                = "example-asg"
  vpc_zone_identifier = ["subnet-12345678", "subnet-87654321"]
  min_size            = 2
  max_size            = 10
  desired_capacity    = 4

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.example.id
        version            = "$Latest"
      }

      override {
        instance_type     = "t3.micro"
        weighted_capacity = "1"
      }
      override {
        instance_type     = "t3.small"
        weighted_capacity = "2"
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 25
      spot_allocation_strategy                 = "capacity-optimized"
    }
  }

  tag {
    key                 = "Name"
    value               = "ASG-Instance"
    propagate_at_launch = true
  }
}