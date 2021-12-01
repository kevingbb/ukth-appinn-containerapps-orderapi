# Hands-on with Container Apps

The purpose of this repo is to help you quickly get hands-on with Container Apps. It is meant to be consumed either through GitHub codespaces or through a local Dev Container. The idea being that everything you need from tooling to runtimes is already included in the Dev Container so it should be as simple as executing a run command.

* **Date:** 13th December 2021
* **Squad:** Cloud Native
* **Duration:** 30 minutes

## Pre-requisites

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

We'll deploy the first version of the application to Azure. This typically takes around 3 to 5 minutes to complete.

```bash
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
storeURL=https://storeapp.$(az containerapp env show -g $resourceGroup -n $containerAppEnv --query 'defaultDomain' -o tsv)/store
```

Let's see what happens if we call the URL of the store with curl.

> Alternatively, you can run `echo $storeURL` to get the URL for the application and then open that in a browser.

```bash
curl $storeURL
```

The response you should see is `[]` which means no data was returned. Something's not working, but what?

ContainerApps integrates with Application Insights and Log Analytics. In the Azure Portal, go to the Log Analytics workspace in the resource group we're using for this demo and run the following query to view the logs for the `queuereader` application.

```
ContainerAppConsoleLogs_CL
| where ContainerAppName_s has "queuereader" and ContainerName_s has "queuereader"
| where Log_s has "null"
| project TimeGenerated, ContainerAppName_s, RevisionName_s, ContainerName_s, Log_s
| order by TimeGenerated desc
```

You should see a number of log file entries which will likely all contain the same error. Drill down on one of them to reveal more. You should see something like the following:

![Image of an Azure Log Analytics log entry showing an error from the queuereader application indicating that a config value is missing](/images/LogAnalyticsDaprPortError.png)

Looks like we're missing a configuration value relating to Dapr. So, we've gone ahead and made the necessary changes to our code and packaged that up in version 2 of our application's container. Let's deploy version 2.

### Deploy Version 2

We'll repeat the deployment command from earlier, but we've updated our template to use version 2 of the queuereader application.

```bash
az deployment group create \
  -g $resourceGroup \
  --template-file v2_template.json \
  --parameters @v2_parameters.json \
  --parameters ContainerApps.Environment.Name=$containerAppEnv \
    LogAnalytics.Workspace.Name=$logAnalytics \
    AppInsights.Name=$appInsights \
    StorageAccount.Name=$storageAccount
```

This time, we'll store the URL for the HTTP API application in a variable

```bash
dataURL=https://httpapi.$(az containerapp env show -g $resourceGroup -n ${name}-env --query 'defaultDomain' -o tsv)/Data
```

Now let's see what happens if we access that URL

> As before, you can type `echo $dataURL` to get the URL of the HTTP API and then open it in a browser if you prefer

``` bash
curl $dataURL
```

The result tells us that `demoqueue` has no messages:

> `Queue 'demoqueue' has 0 messages`

We can call the HTTP API endpoint to add a test message.

```bash
curl -X POST $dataURL?message=test
```

Ok, let's check our Store URL and see what happens this time

```bash
# Check StoreApp Again
curl $storeURL
# Hmmm... where is the message? Let's look at the application code.
#DataController.cs
# Ahhh... we see that the message is not being sent.
# Let's make the necessary changes to the solution and deploy again, but this time let's do a controlled
# traffic split and only send 20% of requests to the new endpoint.
```

### Deploy v3

```bash
az deployment group create \
  -g $resourceGroup \
  --template-file v3_template.json \
  --parameters @v3_parameters.json \
  --parameters ContainerApps.Environment.Name=$containerAppEnv \
    LogAnalytics.Workspace.Name=$logAnalytics \
    AppInsights.Name=$appInsights \
    StorageAccount.Name=$storageAccount
```


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
