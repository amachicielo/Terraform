# Configure providers
provider "aws" {
  region = "us-west-2"
}

provider "azurerm" {
  features {}
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
}

# Deploy AWS resources
resource "aws_instance" "example" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  tags = {
    Name = "example-aws-instance"
  }
}

# Deploy Azure resources
resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "East US"
}

resource "azurerm_virtual_machine" "example" {
  name                  = "example-vm"
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = [azurerm_network_interface.example.id]
  vm_size               = "Standard_DS1_v2"

  # Add OS and storage configuration here
}

# Configure Datadog monitors
resource "datadog_monitor" "aws_cpu" {
  name    = "High CPU Usage - AWS"
  type    = "metric alert"
  message = "CPU usage is high on AWS instance {{host.name}}."
  query   = "avg(last_5m):avg:aws.ec2.cpu{host:${aws_instance.example.id}} > 80"

  monitor_thresholds {
    critical = 80
  }
}

resource "datadog_monitor" "azure_cpu" {
  name    = "High CPU Usage - Azure"
  type    = "metric alert"
  message = "CPU usage is high on Azure VM {{host.name}}."
  query   = "avg(last_5m):avg:azure.vm.percentage_cpu{resource_group:${azurerm_resource_group.example.
    name},name:${azurerm_virtual_machine.example.name}} > 80"

  monitor_thresholds {
    critical = 80
  }
}

# Output the Datadog dashboard URL
resource "datadog_dashboard" "multi_cloud" {
  title       = "Multi-Cloud Overview"
  description = "Overview of AWS and Azure resources"
  layout_type = "ordered"

  widget {
    timeseries_definition {
      title = "CPU Usage - AWS vs Azure"
      request {
        q    = "avg:aws.ec2.cpu{host:${aws_instance.example.id}}"
        display_type = "line"
      }
      request {
        q    = "avg:azure.vm.percentage_cpu{resource_group:$
          {azurerm_resource_group.example.name},name:${azurerm_virtual_machine.example.name}}"
        display_type = "line"
      }
    }
  }
}

output "datadog_dashboard_url" {
  value = "https://app.datadoghq.com/dashboard/${datadog_dashboard.multi_cloud.id}"
}