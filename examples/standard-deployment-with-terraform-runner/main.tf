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
  }
}

locals {
  # Id of the Azure AD tenant that you want to offer your service in.
  tenant_id = "..."

  # Id of the Azure Subscription that should host the service broker container and state.
  subscription_id = "..."

  # SSH clone URL of the git repository that you want to use for managing instances
  # Example: git@github.com:likvid-bank/networking-services.git
  unipipe_git_remote = "..."
  # Public key fingerprints of the git server
  # Example:
  #   github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
  #   github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
  #   github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
  known_hosts = <<EOT
EOT
}

provider "azuread" {
  tenant_id = local.tenant_id
}

provider "azurerm" {
  tenant_id       = local.tenant_id
  subscription_id = local.subscription_id
  features {}
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

  unipipe_git_remote          = local.unipipe_git_remote
  unipipe_git_branch          = "main"
  unipipe_basic_auth_username = "marketplace"

  deploy_terraform_runner = true
  terraform_runner_environment_variables = {
    "TF_VAR_platform_secret" = azuread_service_principal_password.unipipe_pizza.value
    "ARM_TENANT_ID"          = local.tenant_id
    "ARM_SUBSCRIPTION_ID"    = local.subscription_id
    "ARM_CLIENT_ID"          = azuread_application.unipipe_pizza.application_id
    "ARM_CLIENT_SECRET"      = azuread_service_principal_password.unipipe_pizza.value
    "KNOWN_HOSTS"            = local.known_hosts
  }

  depends_on = [
    azurerm_resource_group.unipipe_pizza
  ]
}

#
# Helper files for local development
#
output "env_sh" {
  value = "Tipp: Source the file env.sh before executing `unipipe terraform` by running `source env.sh`."
}
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

output "env_ps1" {
  value = "Tipp: Dot source the file env.ps1 before executing `unipipe terraform` in powershell by running `. env.ps1`."
}
resource "local_file" "env_ps1" {
  content  = <<EOT
# This file stores sensitive information. Never commit this file to version control!
$Env:TF_VAR_platform_secret="${azuread_service_principal_password.unipipe_pizza.value}"
$Env:ARM_TENANT_ID="${local.tenant_id}"
$Env:ARM_SUBSCRIPTION_ID="${local.subscription_id}"
$Env:ARM_CLIENT_ID="${azuread_application.unipipe_pizza.application_id}"
$Env:ARM_CLIENT_SECRET="${azuread_service_principal_password.unipipe_pizza.value}"
EOT
  filename = "env.ps1"
}

resource "local_file" "gitignore" {
  content  = <<EOT
# Do not commit local helper files that may contain secrets.
env.ps1
env.sh
EOT
  filename = ".gitignore"
}
