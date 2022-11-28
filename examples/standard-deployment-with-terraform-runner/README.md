# Standard deployment with unipipe terraform runner

This example spins up UniPipe service broker and terraform runner.

It also creates a service principal and grants terraform runner access to this principal.

```mermaid
flowchart LR;

unipipe_git_remote[SSH clone URL defined by input `unipipe_git_remote` ]
unipipe_git_remote --> instanceRepoURL
unipipe_git_remote --> tr-instanceRepoURL

unipipe_git_ssh_key[private SSH key]
unipipe_git_ssh_key --> sshKey
unipipe_git_ssh_key --> tr-sshKey
unipipe_git_ssh_key_public[public SSH key]
unipipe_git_ssh_key --derive--> unipipe_git_ssh_key_public

subgraph service-broker[unipipe-service-broker container in Azure]
    instanceRepoURL[instance repository clone URL]
    sshKey[Private SSH Key]
    username[basic auth username]
    password[basic auth password]
    containerUrl[container URL]
end

subgraph terraform-runner[unipipe-terraform-runner container in Azure]
    tr-instanceRepoURL[instance repository clone URL]
    tr-sshKey[Private SSH Key]
		service_principal_credentials[Service Principal Credentials]
end

service_principal[Service Principal in AAD]
service_principal_credentials <--> service_principal

tfoutput[Terraform Output]

username --> tfoutput
password --> tfoutput
containerUrl --> tfoutput
unipipe_git_ssh_key_public --> tfoutput
```

## How to use this example

Copy the files.

```sh
curl https://raw.githubusercontent.com/meshcloud/terraform-azure-unipipe/main/examples/standard-deployment-with-terraform-runner/main.tf > main.tf
curl https://raw.githubusercontent.com/meshcloud/terraform-azure-unipipe/main/examples/standard-deployment-with-terraform-runner/outputs.tf > outputs.tf
```

Replace all occurrences of "..." with proper values.

Run `terraform init` and then `terraform apply`.
