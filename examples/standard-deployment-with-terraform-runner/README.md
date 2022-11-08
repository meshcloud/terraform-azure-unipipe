# Standard deployment with GitHub integration

This example spins up an UniPipe service broker with a GitHub repository as instance repository.

```mermaid
flowchart LR;

subgraph repo[GitHub Repository]
    deployKey[Deploy Key with write access]
    cloneUrl[repository clone URL]
end

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
end

tfoutput[Terraform Output]

username --> tfoutput
password --> tfoutput
containerUrl --> tfoutput
sshKey --register public key--> deployKey
tr-sshKey <-- same key --> sshKey
cloneUrl --register clone URL--> instanceRepoURL
```

## How to use this example

Copy the files.

```sh
curl https://raw.githubusercontent.com/meshcloud/terraform-azure-unipipe/main/examples/standard-deployment-with-terraform-runner/main.tf > main.tf
curl https://raw.githubusercontent.com/meshcloud/terraform-azure-unipipe/main/examples/standard-deployment-with-terraform-runner/outputs.tf > outputs.tf
```

Replace all occurrences of "..." with proper values.

Run `terraform init` and then `terraform apply`.
