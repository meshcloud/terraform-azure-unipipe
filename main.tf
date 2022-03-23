terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
  }
}


locals {
  #postfix for preventing already-in-use errors
  resource_group_name_postfix          = "${var.resource_group_name}-${random_string.postfix.result}"
  dns_postfix                          = "${var.dns_name_label}-${random_string.postfix.result}"
  unipipe_storage_account_name_postfix = "unipipeosb${random_string.postfix.result}"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
provider "tls" {
}

provider "random" {
}

# setup key pair for accesing the git repository
# this setup will store the private key in your terrraform state and is thus not recommended for production use cases
resource "tls_private_key" "unipipe_git_ssh_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

# first we need a resource group
resource "azurerm_resource_group" "unipipe" {
  name     = local.resource_group_name_postfix
  location = var.location
}

# setup a storage account with a file share, will be later used by caddi to store ACME challenge files
resource "azurerm_storage_account" "unipipe" {
  name                      = local.unipipe_storage_account_name_postfix
  resource_group_name       = azurerm_resource_group.unipipe.name
  location                  = azurerm_resource_group.unipipe.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true
}

resource "azurerm_storage_share" "acishare" {
  name                 = "acishare"
  storage_account_name = azurerm_storage_account.unipipe.name
}

# setup a random password for the OSB instance
resource "random_password" "unipipe_basic_auth_password" {
  length  = 16
  special = false
}

resource "random_string" "postfix" {
  length  = 4
  special = false
  lower   = true
  upper   = false
}

# setup container group
resource "azurerm_container_group" "unipipe_with_ssl" {
  resource_group_name = azurerm_resource_group.unipipe.name
  location            = var.location
  name                = "unipipe-with-ssl"
  os_type             = "Linux"
  dns_name_label      = local.dns_postfix
  ip_address_type     = "public"

  container {
    name   = "app"
    image  = "ghcr.io/meshcloud/unipipe-service-broker:${var.unipipe_version}"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 8075
      protocol = "TCP"
    }

    secure_environment_variables = {
      "GIT_REMOTE"              = var.unipipe_git_remote
      "GIT_REMOTE_BRANCH"       = var.unipipe_git_branch
      "GIT_SSH_KEY"             = tls_private_key.unipipe_git_ssh_key.private_key_pem
      "APP_BASIC_AUTH_USERNAME" = var.unipipe_basic_auth_username
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
