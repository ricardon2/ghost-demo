Create a template spec:
az ts create \
  --name functionAppSpec \
  --version "1.0" \
  --resource-group rg-sandbox-azl \
  --location "westeurope" \
  --template-file "./functionAppSpec.bicep" 

Deploy a template spec:
id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/templateSpecsRG/providers/Microsoft.Resources/templateSpecs/functionAppSpec/versions/1.0"

az deployment group create \
  --resource-group rg-sandbox-azl \
  --template-spec $id \
  --parameters applicationName='tsdemo'