provider "aws" {
  region = "us-west-2"  # Primary region
}

provider "aws" {
  alias  = "dr"
  region = "us-east-1"  # DR region
}

# Create S3 bucket for backup storage
resource "aws_s3_bucket" "backup" {
  bucket = "example-dr-backup-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    enabled = true

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 90
    }
  }
}

# Create EC2 instance for the primary site
resource "aws_instance" "primary" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  tags = {
    Name = "primary-instance"
  }
}

# Create EBS volume for data replication
resource "aws_ebs_volume" "primary_data" {
  availability_zone = aws_instance.primary.availability_zone
  size              = 100
  type              = "gp3"

  tags = {
    Name = "primary-data-volume"
  }
}

# Attach EBS volume to the primary instance
resource "aws_volume_attachment" "primary_data_attachment" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.primary_data.id
  instance_id = aws_instance.primary.id
}

# Create AWS Elastic Disaster Recovery (DRS) replication configuration
resource "aws_drs_replication_configuration_template" "example" {
  source_server {
    instance_type = "t3.micro"
    
    tags = {
      Name = "DR-Replica"
    }
  }
  
  ebs_encryption {
    kms_key_id = aws_kms_key.dr_key.arn
  }
}

# Create KMS key for DR encryption
resource "aws_kms_key" "dr_key" {
  description             = "KMS key for DR encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

# Create CloudWatch event rule to trigger DR failover
resource "aws_cloudwatch_event_rule" "dr_failover" {
  name        = "dr-failover-trigger"
  description = "Triggers DR failover process"

  event_pattern = jsonencode({
    "source": ["aws.health"],
    "detail-type": ["AWS Health Event"],
    "detail": {
      "service": ["EC2"],
      "eventTypeCategory": ["issue"],
      "region": ["us-west-2"]
    }
  })
}

# Create Lambda function to handle DR failover
resource "aws_lambda_function" "dr_failover" {
  filename      = "dr_failover_function.zip"
  function_name = "dr-failover-handler"
  role          = aws_iam_role.dr_lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"

  environment {
    variables = {
      DR_CONFIGURATION_ID = aws_drs_replication_configuration_template.example.id
    }
  }
}

# Create IAM role for Lambda function
resource "aws_iam_role" "dr_lambda_role" {
  name = "dr-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach CloudWatch event to Lambda function
resource "aws_cloudwatch_event_target" "dr_failover" {
  rule      = aws_cloudwatch_event_rule.dr_failover.name
  target_id = "TriggerDRFailover"
  arn       = aws_lambda_function.dr_failover.arn
}