# environments/main.tf

locals {
  environment = terraform.workspace
}

module "network" {
  source = "../modules/network"
  environment = local.environment
}

module "compute" {
  source = "../modules/compute"
  environment = local.environment
}

# Add more modules as needed
