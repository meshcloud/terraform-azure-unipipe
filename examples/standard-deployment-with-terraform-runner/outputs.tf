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
