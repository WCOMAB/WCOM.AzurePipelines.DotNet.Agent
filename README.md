# Azure DevOps Pipelines .NET Agent docker image

[![Build Status](https://dev.azure.com/wcom/General/_apis/build/status%2FWCOM.AzurePipelines.DotNet.Agent?branchName=main)](https://dev.azure.com/wcom/General/_build/latest?definitionId=105&branchName=main)

Docker image which can be used to build Azure Pipelines .NET workloads running on i.e. in a AKS cluster.

## Installed SDKs

* .NET 8
* .NET 9
* Azure CLI
* Node LTS
* Buildah (Container tagging and publishing)

## Environment variables

* `AZP_TOKEN` - Azure DevOps PAT used to register agent
* `AZP_URL` - Azure DevOps org base url
* `AZP_POOL` - Azure Pipelines Agent pool to register with.
* `AZP_ARGS`- Optional variable for arguments to the build agent i.e. `--once`.
