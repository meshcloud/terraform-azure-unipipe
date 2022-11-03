variable "unipipe_git_remote" {
  type        = string
  description = "git repo URL, use a deploy key (GitHub) or similar to setup an automation user SSH key for unipipe"
}
# ---------------------------------------------------------------------------------------------------------------------
# TERRAFORM RUNNER PARAMETERS
# Set these variables if you want to deploy terraform runner
# ---------------------------------------------------------------------------------------------------------------------
variable "deploy_terraform_runner" {
  type        = bool
  default     = false
  description = "Set this to true if you want to use UniPipe terraform runner"
}
variable "terraform_runner_environment_variables" {
  type        = map(string)
  default     = {}
  description = "Set additional environment variables for terraform-runner container. To authenticate Azure, pass ARM_TENANT_ID, ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID, ARM_SECRET_ID."
}
# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------
variable "resource_group_name" {
  type        = string
  default     = "rg-unipipe-demo"
  description = "Name of the resource group to deploy unipipe"
}
variable "location" {
  type        = string
  default     = "West Europe"
  description = "The Azure region to use for deployment"
}
variable "location_tag" {
  type        = string
  default     = "westeurope"
  description = "location tag, needs to match the location variable"
}
variable "dns_name_label" {
  type        = string
  default     = "unipipe-demo"
  description = "controls the hostname for the FQDN auto-generated by Azure ACI"
}
variable "unipipe_version" {
  type        = string
  default     = "latest"
  description = "unipipe version, see https://github.com/meshcloud/unipipe-service-broker/releases"
}
variable "unipipe_basic_auth_username" {
  type        = string
  default     = "user"
  description = "OSB API basic auth username. Password will be generated by terraform."
}
variable "unipipe_git_branch" {
  type        = string
  default     = "main"
  description = "git branch name"
}
