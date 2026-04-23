targetScope = 'resourceGroup'

@description('Region deployment')
param location string = 'southeastasia'

@description('Project tags')
param tags object = {
  project: 'gapmap'
  env: 'dev'
  team: 'datathon2026'
}

@description('Suffix untuk resource yang perlu global uniqueness')
param uniqueSuffix string = toLower(uniqueString(resourceGroup().id))

@description('Nama resource group target. Dipakai untuk output metadata saja.')
param resourceGroupName string = 'rg-gapmap-jabar-dev'

@description('Storage account name harus lowercase 3-24 char tanpa simbol')
param storageAccountName string = 'stgapmapjabar${take(uniqueSuffix, 6)}'

param amlWorkspaceName string = 'aml-gapmap-jabar'
param amlComputeName string = 'cpu-cluster-dev'
param mapsAccountName string = 'maps-gapmap-jabar'
param functionPlanName string = 'plan-gapmap-func-dev'
param functionAppName string = 'func-gapmap-api'
param appInsightsName string = 'appi-gapmap-jabar'
param staticWebAppName string = 'stapp-gapmap-dashboard'
param keyVaultName string = 'kv-gapmap-jabar'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: true
    minimumTlsVersion: 'TLS1_2'
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource containerRaw 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'raw-data'
  properties: {
    publicAccess: 'None'
  }
}

resource containerProcessed 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'processed-data'
  properties: {
    publicAccess: 'None'
  }
}

resource containerModels 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'models'
  properties: {
    publicAccess: 'None'
  }
}

resource containerWebAssets 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'web-assets'
  properties: {
    publicAccess: 'Blob'
  }
}

resource storageMgmtPolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'delete-raw-data-after-90-days'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: 90
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                'raw-data/'
              ]
            }
          }
        }
      ]
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    accessPolicies: []
    publicNetworkAccess: 'Enabled'
  }
}

resource amlWorkspace 'Microsoft.MachineLearningServices/workspaces@2023-04-01' = {
  name: amlWorkspaceName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: amlWorkspaceName
    storageAccount: storage.id
    keyVault: keyVault.id
    applicationInsights: appInsights.id
  }
}

resource amlCompute 'Microsoft.MachineLearningServices/workspaces/computes@2025-04-01' = {
  parent: amlWorkspace
  name: amlComputeName
  location: location
  properties: {
    computeType: 'AmlCompute'
    properties: {
      vmSize: 'Standard_DS2_v2'
      scaleSettings: {
        minNodeCount: 0
        maxNodeCount: 2
      }
    }
  }
}

resource mapsAccount 'Microsoft.Maps/accounts@2023-06-01' = {
  name: mapsAccountName
  location: location
  tags: tags
  kind: 'Gen2'
  sku: {
    name: 'G2'
  }
}

resource functionPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: functionPlanName
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
}

var storageAccountKey = storage.listKeys().keys[0].value
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storageAccountKey};EndpointSuffix=${environment().suffixes.storage}'

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: functionPlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Python|3.11'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}

resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' = {
  name: staticWebAppName
  location: location
  tags: tags
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {}
}

var mapsPrimaryKey = mapsAccount.listKeys().primaryKey

resource secretMapsKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AZURE-MAPS-KEY'
  properties: {
    value: mapsPrimaryKey
  }
}

resource secretStorageKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'STORAGE-ACCOUNT-KEY'
  properties: {
    value: storageAccountKey
  }
}

resource secretSubscriptionId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AML-SUBSCRIPTION-ID'
  properties: {
    value: subscription().subscriptionId
  }
}

output outResourceGroup string = resourceGroupName
output outStorageAccountName string = storage.name
output outAmlWorkspaceName string = amlWorkspace.name
output outAmlComputeName string = amlCompute.name
output outMapsAccountName string = mapsAccount.name
@secure()
output outMapsPrimaryKey string = mapsPrimaryKey
output outFunctionAppName string = functionApp.name
output outStaticWebAppName string = staticWebApp.name
output outKeyVaultName string = keyVault.name
