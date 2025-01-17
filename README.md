# Summary
This is a PoC that gives you an example of how to implement a highly available deployment of [ghost](https://ghost.org/docs/).

## Terraform
You must have terraform installed and configured in your machine
So you can move the IaC\terraform and execute:

```terraform
terraform init
terraform plan -out=poc.tfplan
terraform apply "poc.tfplan"
```

To erase everything you can execute:
```terraform
terraform apply -destroy
```

it is also important you create a terraform.tfvars document within this directory and add credentials you will you to set up MySQL instance

```terraform
mysql_administrator_login = "admin"
mysql_administrator_login_password = "P@$$w0rd!"
```

you can learn more about how to set up your your environment for Azure [here](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_certificate)

## Bicep

```bicep
az deployment group create -g rg-sandbox-azl -f main.bicep --confirm-with-what-if
```

## Pipeline Config
https://learn.microsoft.com/en-us/azure/app-service/deploy-container-github-action?tabs=publish-profile

## Non-Compliant
[Preview]: Container Registry should be Zone Redundant

### Remediation
Update Container Registry with
```bicep
zoneRedundancy: 'Enabled' 
```

## Exemption
[Preview]: Storage Accounts should be Zone Redundant
To remove an Initiative or Policy, you must use the management group. But if you just want to disable it in a specific place, you create an exemption.
