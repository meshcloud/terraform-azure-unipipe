terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.29.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">=4.0.4"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.4.3"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# BASIC AUTH PASSWORD
# If var.unipipe_basic_auth_password is null, the setup will generate a password and store it in your terrraform state.
# ---------------------------------------------------------------------------------------------------------------------
resource "random_password" "unipipe_basic_auth_password" {
  count   = var.unipipe_basic_auth_password == null ? 1 : 0
  length  = 64
  special = false
}

locals {
  unipipe_basic_auth_password = var.unipipe_basic_auth_password != null ? var.unipipe_basic_auth_password : random_password.unipipe_basic_auth_password[0].result
}

# ---------------------------------------------------------------------------------------------------------------------
# SSH KEY
# If var.private_key_pem is null, the setup will generate a private key and store it in your terrraform state.
# ---------------------------------------------------------------------------------------------------------------------
resource "tls_private_key" "unipipe_git_ssh_key" {
  count       = var.private_key_pem == null ? 1 : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

locals {
  unipipe_git_ssh_key = var.private_key_pem != null ? var.private_key_pem : tls_private_key.unipipe_git_ssh_key[0].private_key_pem
}

data "tls_public_key" "unipipe_git_ssh_key" {
  private_key_pem = local.unipipe_git_ssh_key
}

# ---------------------------------------------------------------------------------------------------------------------
# AZURE RESOURCES
# ---------------------------------------------------------------------------------------------------------------------
data "azurerm_resource_group" "unipipe" {
  name = var.resource_group_name
}

# storage account with file share to store ACME challenge files for caddy
resource "azurerm_storage_account" "unipipe" {
  name                      = local.unipipe_storage_account_name_postfix
  resource_group_name       = data.azurerm_resource_group.unipipe.name
  location                  = data.azurerm_resource_group.unipipe.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true
}

resource "azurerm_storage_share" "caddy" {
  name                 = "caddy"
  storage_account_name = azurerm_storage_account.unipipe.name
  quota                = 1
}

resource "azurerm_container_group" "unipipe_service_broker" {
  resource_group_name = data.azurerm_resource_group.unipipe.name
  location            = var.location
  name                = "unipipe-service-broker"
  os_type             = "Linux"
  dns_name_label      = local.dns_postfix
  ip_address_type     = "Public"

  exposed_port {
    port     = 443
    protocol = "TCP"
  }

  exposed_port {
    port     = 80
    protocol = "TCP"
  }

  container {
    name   = "app"
    image  = "ghcr.io/meshcloud/unipipe-service-broker:${var.unipipe_version}"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 8075
      protocol = "TCP"
    }

    environment_variables = {
      "GIT_REMOTE"              = var.unipipe_git_remote
      "GIT_REMOTE_BRANCH"       = var.unipipe_git_branch
      "APP_BASIC_AUTH_USERNAME" = var.unipipe_basic_auth_username
    }

    secure_environment_variables = {
      "GIT_SSH_KEY"             = local.unipipe_git_ssh_key
      "APP_BASIC_AUTH_PASSWORD" = local.unipipe_basic_auth_password
    }
  }

  container {
    name   = "caddy"
    image  = "caddy"
    cpu    = "0.05"
    memory = "0.1"

    ports {
      port     = 443
      protocol = "TCP"
    }

    ports {
      port     = 80
      protocol = "TCP"
    }

    volume {
      name                 = "aci-caddy-data"
      mount_path           = "/data"
      storage_account_name = azurerm_storage_account.unipipe.name
      storage_account_key  = azurerm_storage_account.unipipe.primary_access_key
      share_name           = azurerm_storage_share.caddy.name
    }

    # instead of a caddyfile, we use CLI options
    commands = ["caddy", "reverse-proxy", "--from", "${local.dns_postfix}.${var.location_tag}.azurecontainer.io", "--to", "localhost:8075"]
  }
}

resource "azurerm_container_group" "unipipe_terraform_runner" {
  count = var.deploy_terraform_runner ? 1 : 0

  resource_group_name = data.azurerm_resource_group.unipipe.name
  location            = var.location
  name                = "unipipe-terraform-runner"
  os_type             = "Linux"
  ip_address_type     = "None"

  container {
    name   = "app"
    image  = "ghcr.io/meshcloud/unipipe-terraform-runner:${var.unipipe_version}"
    cpu    = "0.5"
    memory = "0.5"

    environment_variables = {
      "GIT_USER_EMAIL" = "unipipe-terraform-runner@meshcloud.io"
      "GIT_USER_NAME"  = "Terraform Runner"
      "GIT_REMOTE"     = var.unipipe_git_remote
    }

    secure_environment_variables = merge({
      "GIT_SSH_KEY" = local.unipipe_git_ssh_key
    }, var.terraform_runner_environment_variables)
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# POSTFIXES
# Postfixes are used to avoid naming conflicts.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  #postfix for preventing already-in-use errors
  dns_postfix                          = "${var.dns_name_label}-${random_string.postfix.result}"
  unipipe_storage_account_name_postfix = "unipipeservicebroker${random_string.postfix.result}"
}

resource "random_string" "postfix" {
  length  = 4
  special = false
  lower   = true
  upper   = false
}


# ---------------------------------------------------------------------------------------------------------------------
# MOVED
# Making module updates easier
# ---------------------------------------------------------------------------------------------------------------------
moved {
  from = azurerm_storage_share.acishare
  to   = azurerm_storage_share.caddy
}
moved {
  from = azurerm_container_group.unipipe_with_ssl
  to   = azurerm_container_group.unipipe_service_broker
}
moved {
  from = tls_private_key.unipipe_git_ssh_key
  to   = tls_private_key.unipipe_git_ssh_key[0]
}
moved {
  from = random_password.unipipe_basic_auth_password
  to   = random_password.unipipe_basic_auth_password[0]
}

