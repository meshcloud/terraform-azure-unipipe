# terraform-azure-unipipe
UniPipe Service Broker is an open source project for offering services. Azure is a proprietary public cloud platform provided by Microsoft.

This terraform module provides a setup UniPipe Service Broker on Azure.

This setup will store the private key in your terrraform state and is thus __not recommended for production use cases__.

## Prerequisites

- [Terraform installed](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [Azure CLI installed](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (already installed in Azure Portal)
