# Configure the AWS provider
provider "aws" {
  region = "us-west-2"
}

# Create an RDS instance
resource "aws_db_instance" "example" {
  identifier        = "example-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name           = "myapp"
  username          = var.db_username
  password          = var.db_password

  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.example.name

  skip_final_snapshot = true
}

# Create a security group for the RDS instance
resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Security group for RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Adjust this to your VPC CIDR
  }
}

# Create a DB subnet group
resource "aws_db_subnet_group" "example" {
  name       = "example-db-subnet-group"
  subnet_ids = var.subnet_ids
}

# Define the database migration script
data "template_file" "migration_script" {
  template = file("${path.module}/migrations/V1__initial_schema.sql")
}

# Execute the migration script
resource "null_resource" "db_migration" {
  triggers = {
    migration_hash = sha256(data.template_file.migration_script.rendered)
  }

  provisioner "local-exec" {
    command = <<EOF
      mysql -h ${aws_db_instance.example.endpoint} -u ${var.db_username} -p${var.db_password} 
        ${aws_db_instance.example.db_name} < ${path.module}/migrations/V1__initial_schema.sql
    EOF
  }

  depends_on = [aws_db_instance.example]
}

# Output the database endpoint
output "db_endpoint" {
  value = aws_db_instance.example.endpoint
}

