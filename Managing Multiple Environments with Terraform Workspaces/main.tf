# Define the workspace variable
variable "environment" {
  type = string
  default = terraform.workspace
}

# Configure the AWS provider
provider "aws" {
  region = var.region
}

# Define environment-specific variables
variable "instance_type" {
  type = map(string)
  default = {
    default = "t2.micro"
    dev     = "t2.small"
    prod    = "t2.medium"
  }
}

# Create an EC2 instance based on the workspace
resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = var.instance_type[terraform.workspace]
  tags = {
    Name = "example-instance-${terraform.workspace}"
  }
}
