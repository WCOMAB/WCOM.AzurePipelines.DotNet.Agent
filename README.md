# Azure DevOps Pipelines .NET Agent docker image

[![Build Status](https://dev.azure.com/wcom/General/_apis/build/status%2FWCOM.AzurePipelines.DotNet.Agent?branchName=main)](https://dev.azure.com/wcom/General/_build/latest?definitionId=105&branchName=main)

Docker image which can be used to build Azure Pipelines .NET workloads running on i.e. in a AKS cluster. Based on Ubuntu 26.04.

## SDKs

* .NET 8
* .NET 9
* .NET 10
* .NET 11 (RC1 / go-live)
* Node 18
* Node 20
* Node 22
* Node 24 (fnm default)
* pnpm

## Azure

* Azure CLI
* Azure Developer CLI (`azd`)
* Bicep (standalone binary and `az bicep`)

## Containers and Kubernetes

* Buildah (container tagging and publishing)
* Skopeo
* Crane (container archive publishing)
* regctl
* kubectl

## SQL

* sqlcmd (Go), bcp, and the Microsoft SQL ODBC driver
* sqlpackage

## Tools

* Playwright browser system dependencies (jobs install their own browsers)
* Azurite
* Renovate
* Cake
* dpi
* dotnet-outdated

## Coding agents

* Cursor CLI (`cursor-agent`)
* Claude Code with the official .NET plugin set

## Environment variables

* `AZP_TOKEN` - Azure DevOps PAT used to register agent
* `AZP_URL` - Azure DevOps org base url
* `AZP_POOL` - Azure Pipelines Agent pool to register with.
* `AZP_ARGS`- Optional variable for arguments to the build agent i.e. `--once`.
