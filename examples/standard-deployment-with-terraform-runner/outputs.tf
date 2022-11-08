output "unipipe_basic_auth_username" {
  value = module.unipipe.unipipe_basic_auth_username
}

output "unipipe_basic_auth_password" {
  value     = module.unipipe.unipipe_basic_auth_password
  sensitive = true
}

output "url" {
  value = module.unipipe.url
}

output "how-to-continue" {
  value = <<EOT
1. Run `unipipe generate terraform-runner-hello-world` in the repository root. This will generate a minimal service definition and terraform files for working with service instances.
2. Register your service broker with the marketplace using the terraform outputs of this workspace.
3. Order an instance of your new service via the marketplace.
EOT
}
