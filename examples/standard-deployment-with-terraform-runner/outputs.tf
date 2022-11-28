output "unipipe_basic_auth_username" {
  value = module.unipipe.unipipe_basic_auth_username
  description = "Use this username when registering the Service Broker in the marketplace."
}

output "unipipe_basic_auth_password" {
  value     = module.unipipe.unipipe_basic_auth_password
  sensitive = true
  description = "Use this password when registering the Service Broker in the marketplace."
}

output "url" {
  value = module.unipipe.url
  description = "Use this URL when registering the Service Broker in the marketplace."
}

output "unipipe_git_ssh_key" {
  value = module.unipipe.unipipe_git_ssh_key
  description = "This SSH key needs write access to the git repository."
}

output "how-to-continue" {
  value = <<EOT
1. Grant write permissions on the git repository for the unipipe_git_ssh_key.
2. Run `unipipe generate terraform-runner-hello-world` in the repository root. This will generate a minimal service definition and terraform files for working with service instances.
3. Register your service broker with the marketplace using the terraform outputs of this workspace.
4. Order an instance of your new service via the marketplace.
EOT
}
