output "url" {
  value       = "https://${azurerm_container_group.unipipe_with_ssl.fqdn}"
  description = "UniPipe API URL. If you want access to the catalog page, you can add /v2/catalog at the end of the url."
}

output "unipipe_basic_auth_username" {
  value       = var.unipipe_basic_auth_username
  description = "OSB API basic auth username"
}

output "unipipe_basic_auth_password" {
  value       = random_password.unipipe_basic_auth_password.result
  sensitive   = true
  description = "OSB API basic auth password"
}

output "unipipe_git_ssh_key" {
  value       = tls_private_key.unipipe_git_ssh_key.public_key_openssh
  description = "UniPipe will use this key to access the git repository. You have to give read+write access on the target repository for this key."
}

output "info" {
  value = "UniPipe is starting now. This may take a couple of minutes on Azure ACI. You can use Azure Portal to view logs of the container starting up and debug any issues. Also note that for newly deployed domains Azure ACI can take a few minutes to provide DNS."
}
