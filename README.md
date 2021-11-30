# Hands-on with Container Apps

The purpose of this repo is to help you quickly get hands-on with Container Apps. It is meant to be consumed either through GitHub codespaces or through a local Dev Container. The idea being that everything you need from tooling to runtimes is already included in the Dev Container so it should be as simple as executing a run command.

* **Date:** 13th December 2021
* **Squad:** Cloud Native
* **Duration:** 30 minutes

## Pre-requisites

The purpose of this repo is to help you quickly get hands-on with Container Apps. It is meant to be consumed either through GitHub codespaces or through a local Dev Container. The idea being that everything you need from tooling to runtimes is already included in the Dev Container so it should be as simple as executing a run command.

* **Date:** 8th November 2021
* **Squad:** Cloud Native
* **Duration:** 30 minutes

There are two options:

1. [Access to GitHub Codespaces](#getting-started-via-codespaces)
1. [VS Code + Docker Desktop on Local Machine](#getting-started-via-vs-code-and-local-dev-container)

## Getting Started

As this is currently a preview service, you will need to install an Azure CLI extension to work with Container Apps.

Run the following command.

```bash
az extension add \
  --source https://workerappscliextension.blob.core.windows.net/azure-cli-extension/containerapp-0.2.0-py2.py3-none-any.whl
```

### Setup Solution

Let's start by setting some variables that we will use for creating Azure resources in this demo, and a resource group for those resources to reside in.

```bash
# Demo Setup with Preview Repo

# Generate a random name

name=ca-$(cat /dev/urandom | tr -dc '[:lower:]' | fold -w ${1:-5} | head -n 1)

# Set variables for the rest of the demo

resourceGroup=${name}-rg
location=northeurope
containerAppEnv=${name}-env
logAnalytics=${name}-la
appInsights=${name}-ai
storageAccount=$(echo $name | tr -d -)sa
# Create Resource Group
az group create --name $resourceGroup --location $location -o table
```

### Deploy version 1 of the application

Deploy the first version of the application to Azure. This typically takes around 3 to 5 minutes to complete.

```bash
# Deploy v1 of the Solution (3 - 5 Mins)

az deployment group create \
  -g $resourceGroup \
  --template-file v1_template.json \
  --parameters @v1_parameters.json \
  --parameters ContainerApps.Environment.Name=$containerAppEnv \
    LogAnalytics.Workspace.Name=$logAnalytics \
    AppInsights.Name=$appInsights \
    StorageAccount.Name=$storageAccount

```

Now the application is deployed, let's determine the URL we'll need to use to access it and store that in a variable for convenience

```bash
appURL=https://storeapp.$(az containerapp env show -g $resourceGroup -n $containerAppEnv --query 'defaultDomain' -o tsv)/store
```



```bash
# Check StoreApp Again

curl $appURL

# Hmmm... where is the data? I guess its time for troubleshooting.
# Check Queue Reader Application Logs for Issues

ContainerAppConsoleLogs_CL
| where ContainerAppName_s has "queuereader" and ContainerName_s has "queuereader"
| where Log_s has "null"
| project TimeGenerated, ContainerAppName_s, RevisionName_s, ContainerName_s, Log_s
| order by TimeGenerated desc

# Let's make the necessary changes to the solution and deploy again.
```

### Deploy v2

```bash
# Deploy v2 of the Solution
az deployment group create -g $RG --template-file v2_template.json --parameters @v2_parameters.json
# Let's send some orders.
curl "https://httpapi.$(az containerapp env show -g $RG -n $CAENV --query 'defaultDomain' -o tsv)/Data"
curl -X POST "https://httpapi.$(az containerapp env show -g $RG -n $CAENV --query 'defaultDomain' -o tsv)/Data?message=test"
# Check StoreApp Again
curl "https://storeapp.$(az containerapp env show -g $RG -n $CAENV --query 'defaultDomain' -o tsv)/store"
# Hmmm... where is the message? Let's look at the application code.
#DataController.cs
# Ahhh... we see that the message is not being sent.
# Let's make the necessary changes to the solution and deploy again, but this time let's do a controlled
# traffic split and only send 20% of requests to the new endpoint.
```

### Deploy v3

```bash
# Deploy v3 of the Solution
az deployment group create -g $RG --template-file v3_template.json --parameters @v3_parameters.json
# Let's send some orders.
curl "https://httpapi.$(az containerapp env show -g $RG -n $CAENV --query 'defaultDomain' -o tsv)/Data"
curl -X POST "https://httpapi.$(az containerapp env show -g $RG -n $CAENV --query 'defaultDomain' -o tsv)/Data"
# Check StoreApp Again
curl "https://storeapp.$(az containerapp env show -g $RG -n $CAENV --query 'defaultDomain' -o tsv)/store"
# Let's send a bunch of orders and check out the splitting of traffic.
hey -m POST -n 10 -c 1 "https://httpapi.$(az containerapp env show -g $RG -n $CAENV --query 'defaultDomain' -o tsv)/Data?message=hello"
# Let's check the Queue Reader Application Logs
ContainerAppConsoleLogs_CL
| where ContainerAppName_s has "queuereader" and ContainerName_s has "queuereader"
| where Log_s has "Message"
| project TimeGenerated, Log_s
| order by TimeGenerated desc
# Ahhh... we see that the new changes are now working and only 1 in 5 messages are showing the message.
# Let's now ramp up the changes to 100% and setup the proper scaling rules. For our use case we want to
# make sure we are being cost effective and scaling to zero.
```

# Deploy v4

```bash
# Deploy v4 of the Solution
az deployment group create -g $RG --template-file v4_template.json --parameters @v4_parameters.json
# Let's send a bunch of orders and check out the splitting of traffic.
hey -m POST -n 10 -c 1 "https://httpapi.$(az containerapp env show -g $RG -n $CAENV --query 'defaultDomain' -o tsv)/Data?message=testscale"
# Let's check the number of orders in the queue
curl "https://httpapi.$(az containerapp env show -g $RG -n $CAENV --query 'defaultDomain' -o tsv)/Data"
# Let's check the Queue Reader Application Logs
ContainerAppConsoleLogs_CL
| where ContainerAppName_s has "queuereader" and ContainerName_s has "queuereader"
| where Log_s has "Message"
| project TimeGenerated, Log_s
| order by TimeGenerated desc
# Demonstrate Scaling
# Terminal Setup for Demo
az containerapp list -g $RG --query "[].{Name:name,State:provisioningState}" -o table
while :; do clear; ???; sleep 2; done
RG=khcademo01-rg
while :; do clear; az containerapp list -g $RG --query "[].{Name:name,State:provisioningState}" -o table; sleep 5; done
RG=khcademo01-rg
while :; do clear; az containerapp revision list -g $RG -n queuereader --query "[].{Revision:name,Replicas:replicas,Active:active,Created:createdTime}" -o table; sleep 5; done
RG=khcademo01-rg
while :; do clear; az containerapp revision list -g $RG -n storeapp --query "[].{Revision:name,Replicas:replicas,Active:active,Created:createdTime}" -o table; sleep 5; done
RG=khcademo01-rg
while :; do clear; az containerapp revision list -g $RG -n httpapi --query "[].{Revision:name,Replicas:replicas,Active:active,Created:createdTime}" -o table; sleep 5; done
RG=khcademo01-rg
CAENV=khcaenv001
while :; do clear; curl "https://httpapi.$(az containerapp env show -g $RG -n $CAENV --query 'defaultDomain' -o tsv)/Data"; sleep 5; done
# Simulate a Load
hey -m POST -n 10000 -c 10 "https://httpapi.$(az containerapp env show -g $RG -n $CAENV --query 'defaultDomain' -o tsv)/Data?message=loadtest"
```

### Cleanup

1. Cleanup the Azure Resource Group:

```bash
az group delete -g $RG --no-wait -y
```

## Acknowledgements

* ???

## Contributors

* Kevin Harris - kevin.harris@microsoft.com
* Mahmoud El Zayet - mahmoud.elzayet@microsoft.com
* Mark Whitby - mark.whitby@microsft.com
* Anu Bhattacharya - anulekha.bhattacharya@microsoft.com
