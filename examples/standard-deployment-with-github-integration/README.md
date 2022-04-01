# Standard deployment with GitHub integration

This example spins up an UniPipe service broker with a GitHub repository as instance repository.

```mermaid
flowchart LR;

subgraph repo[GitHub Repository]
    deployKey[Deploy Key with write access]
    cloneUrl[repository clone URL]
end

subgraph unipipe[UniPipe container in Azure]
    instanceRepoURL[instance repository clone URL]
    sshKey[Private SSH Key]
    username[basic auth username]
    password[basic auth password]
    containerUrl[container URL]
end

tfoutput[Terraform Output]

username --> tfoutput
password --> tfoutput
containerUrl --> tfoutput
sshKey --register public key--> deployKey
cloneUrl --register clone URL--> instanceRepoURL
```

## How to use this example

Replace all occurrences of "..." with proper values.

Run `terraform apply`.
