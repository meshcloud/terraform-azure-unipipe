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

locals {
  #postfix for preventing already-in-use errors
  dns_postfix                          = "${var.dns_name_label}-${random_string.postfix.result}"
  unipipe_storage_account_name_postfix = "unipipeservicebroker${random_string.postfix.result}"
}

# setup key pair for accesing the git repository
# this setup will store the private key in your terrraform state and is thus not recommended for production use cases
resource "tls_private_key" "unipipe_git_ssh_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}


data "azurerm_resource_group" "unipipe" {
  name = var.resource_group_name
}

# setup a storage account with a file share, will be later used by caddy to store ACME challenge files
resource "azurerm_storage_account" "unipipe" {
  name                      = local.unipipe_storage_account_name_postfix
  resource_group_name       = data.azurerm_resource_group.unipipe.name
  location                  = data.azurerm_resource_group.unipipe.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true
}

resource "azurerm_storage_share" "acishare" {
  name                 = "acishare"
  storage_account_name = azurerm_storage_account.unipipe.name
  quota                = 1
}

# setup a random password for the OSB instance
resource "random_password" "unipipe_basic_auth_password" {
  length  = 32
  special = false
}

resource "random_string" "postfix" {
  length  = 4
  special = false
  lower   = true
  upper   = false
}

# setup container group: unipipe-service-broker
resource "azurerm_container_group" "unipipe_with_ssl" {
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
      "GIT_SSH_KEY"             = tls_private_key.unipipe_git_ssh_key.private_key_pem
      "APP_BASIC_AUTH_PASSWORD" = random_password.unipipe_basic_auth_password.result
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
      share_name           = azurerm_storage_share.acishare.name
    }

    # instead of a caddyfile, we use CLI options
    commands = ["caddy", "reverse-proxy", "--from", "${local.dns_postfix}.${var.location_tag}.azurecontainer.io", "--to", "localhost:8075"]
  }
}


# setup container group: unipipe-terraform-runner
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
      "GIT_SSH_KEY" = tls_private_key.unipipe_git_ssh_key.private_key_pem
    }, var.terraform_runner_environment_variables)
  }
}
