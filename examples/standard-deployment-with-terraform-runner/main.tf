terraform {
  # Removing the backend will output the terraform state in the local filesystem
  # See https://www.terraform.io/language/settings/backends for more details
  #
  # Remove/comment the backend block below if you are only testing the module.
  # Please be aware that you cannot destroy the created resources via terraform if you lose the state file.
  backend "azurerm" {
    subscription_id      = "..."
    resource_group_name  = "..."
    storage_account_name = "..."
    container_name       = "..."
    key                  = "terraform.tfstate"
  }

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.30.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.29.1"
    }
    github = {
      source  = "integrations/github"
      version = "~>5.7.0"
    }

  }
}

locals {
  # The GitHub organization the instance repostiory lives in.
  github_owner = "..."

  # Id of the Azure AD tenant that you want to offer your service in.
  tenant_id = "..."

  # Id of the Azure Subscription that should host the service broker container and state.
  subscription_id = "..."
}

provider "github" {
  owner = local.github_owner
}

provider "azuread" {
  tenant_id = local.tenant_id
}

provider "azurerm" {
  tenant_id       = local.tenant_id
  subscription_id = local.subscription_id
  features {}
}

data "github_repository" "instance_repository" {
  name = "unipipe-pizza"
}

#
# Service Principal for managing service instances
#
resource "azuread_application" "unipipe_pizza" {
  display_name = "unipipe-pizza"
}

resource "azuread_service_principal" "unipipe_pizza" {
  application_id = azuread_application.unipipe_pizza.application_id
}

resource "azuread_service_principal_password" "unipipe_pizza" {
  service_principal_id = azuread_service_principal.unipipe_pizza.object_id
}

#
# UniPipe service broker + terraform runner on Azure
#
resource "azurerm_resource_group" "unipipe_pizza" {
  name     = "unipipe-pizza"
  location = "West Europe"
}

module "unipipe" {
  source = "git::https://github.com/meshcloud/terraform-azure-unipipe.git/?ref=v0.2"

  resource_group_name = azurerm_resource_group.unipipe_pizza.name

  unipipe_git_remote          = data.github_repository.instance_repository.ssh_clone_url
  unipipe_git_branch          = "main"
  unipipe_basic_auth_username = "marketplace"

  deploy_terraform_runner = true
  terraform_runner_environment_variables = {
    "TF_VAR_platform_secret" = azuread_service_principal_password.unipipe_pizza.value
    "ARM_TENANT_ID"          = local.tenant_id
    "ARM_SUBSCRIPTION_ID"    = local.subscription_id
    "ARM_CLIENT_ID"          = azuread_application.unipipe_pizza.application_id
    "ARM_CLIENT_SECRET"      = azuread_service_principal_password.unipipe_pizza.value
  }

  depends_on = [
    azurerm_resource_group.unipipe_pizza
  ]
}

# Grant the containers access to the GitHub repository.
resource "github_repository_deploy_key" "unipipe_ssh_key" {
  title      = "unipipe-service-broker-deploy-key"
  repository = data.github_repository.instance_repository.name
  key        = module.unipipe.unipipe_git_ssh_key
  read_only  = "false"
}

output "env_sh" {
  value = "Tipp: Source the file env.sh in this directory for local testing with `unipipe terraform`."
}

# local file for testing
resource "local_file" "env_sh" {
  content  = <<EOT
#!/bin/bash
# This file stores sensitive information. Never commit this file to version control!
export TF_VAR_platform_secret="${azuread_service_principal_password.unipipe_pizza.value}"
export ARM_TENANT_ID="${local.tenant_id}"
export ARM_SUBSCRIPTION_ID="${local.subscription_id}"
export ARM_CLIENT_ID="${azuread_application.unipipe_pizza.application_id}"
export ARM_CLIENT_SECRET="${azuread_service_principal_password.unipipe_pizza.value}"
EOT
  filename = "env.sh"
}
