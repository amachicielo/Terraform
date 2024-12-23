# Configure the AWS provider
provider "aws" {
  region = "us-west-2"
}

# Create an IAM role for the Lambda function
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach necessary permissions to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_exec.name
}

# Create a Lambda function
resource "aws_lambda_function" "example" {
  filename      = "lambda_function.zip"
  function_name = "example_lambda_function"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"

  source_code_hash = filebase64sha256("lambda_function.zip")
}

# Create an API Gateway REST API
resource "aws_api_gateway_rest_api" "example" {
  name        = "example_api"
  description = "Example API Gateway REST API"
}

# Create an API Gateway resource
resource "aws_api_gateway_resource" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "example"
}

# Create an API Gateway method
resource "aws_api_gateway_method" "example" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.example.id
  http_method   = "GET"
  authorization = "NONE"
}

# Create an API Gateway integration
resource "aws_api_gateway_integration" "example" {
  rest_api_id             = aws_api_gateway_rest_api.example.id
  resource_id             = aws_api_gateway_resource.example.id
  http_method             = aws_api_gateway_method.example.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.example.invoke_arn
}

# Create an API Gateway deployment
resource "aws_api_gateway_deployment" "example" {
  depends_on = [aws_api_gateway_integration.example]

  rest_api_id = aws_api_gateway_rest_api.example.id
  stage_name  = "prod"
}

# Allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.example.execution_arn}/*/$
    {aws_api_gateway_method.example.http_method}${aws_api_gateway_resource.example.path}"
}

# Output the API Gateway URL
output "api_url" {
  value = "${aws_api_gateway_deployment.example.invoke_url}${aws_api_gateway_resource.example.path}"
}