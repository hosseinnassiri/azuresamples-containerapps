# Azure Container Apps

Azure Container Apps is a serverless platform that allows you to maintain less infrastructure and save costs while running containerized applications.

## Prerequisites

* An Azure account with an active subscription, with the Microsoft.App resource provider registered.
* A GitHub account.
* A GitHub repository to store your Bicep files and your workflow files.
* An environment for the GitHub repository to deploy the code.
* Azure CLI installed.

## Setting up github actions

1. Using OIDC, you need to configure a federated identity credential on a Microsoft Entra application.
2. Using github actions to automate the deployment of bicep templates.
3. Using azure cli to configure the github credentials.

* Create resource group

```azurecli
az group create --name {resource_group_name} --location canadacentral
```

* Create microsoft entra app with service principal

```azurecli
az ad sp create-for-rbac --name {app-name} --role contributor --scopes /subscriptions/{subscription-id}/resourceGroups/{resource_group_name} --json-auth
```

* Configure a federated identity credential on the Microsoft Entra application to trust tokens issued by GitHub Actions to your GitHub repository.

```azurecli
az ad app federated-credential create --id {app-client-id} --parameters credentials.json
("credentials.json" contains the following content)
{
    "name": "github-federationidentity-dev-01",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<Organization/Repository>:environment:<EnvironmentName>",
    "description": "configure federated identity credential",
    "audiences": [
        "api://AzureADTokenExchange"
    ]
}
```

Create secrets for AZURE_CLIENT_ID, AZURE_TENANT_ID, and AZURE_SUBSCRIPTION_ID. Copy these values from your Microsoft Entra application.

Add the following to the workflow yaml file:

```yml
name: ...
permissions:
  id-token: write
  contents: read
```

For more information, visit [Deploy Bicep files by using GitHub Actions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-github-actions?tabs=CLI%2Copenid)
