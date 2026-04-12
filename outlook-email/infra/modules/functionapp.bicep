param name string
@description('Primary location for all resources & Flex Consumption Function App')
param location string = resourceGroup().location
param tags object = {}
param applicationInsightsName string = ''
param appServicePlanId string
param appSettings object = {}
param graphTenantId string = ''
param graphClientId string = ''
@secure()
param graphClientSecret string = ''
@description('Tenant ID of the MCP OAuth resource application that protects the Function App via Easy Auth.')
param mcpAuthTenantId string = ''
@description('Client/application ID of the MCP OAuth resource application that protects the Function App via Easy Auth.')
param mcpAuthClientId string = ''
@description('Optional client/application IDs allowed to call the Function App directly with MCP OAuth tokens.')
param allowedClientApplicationIds array = []
param runtimeName string 
param runtimeVersion string 
param serviceName string = 'mcp'
param storageAccountName string
param deploymentStorageContainerName string
param virtualNetworkSubnetId string = ''
param privateEndpointSubnetResourceId string = ''
param privateDnsZoneResourceId string = ''
param instanceMemoryMB int = 2048
param maximumInstanceCount int = 100
param identityId string = ''
param identityClientId string = ''
param graphUseManagedIdentity bool = true
param enableBlob bool = true
param enableQueue bool = false
param enableTable bool = false
param enableFile bool = false
param azdServiceName string
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'
param disableBasicPublishingCredentials bool = false

@allowed(['SystemAssigned', 'UserAssigned'])
param identityType string = 'UserAssigned'

var applicationInsightsIdentity = 'ClientId=${identityClientId};Authorization=AAD'
var kind = 'functionapp,linux'
var loginEndpoint = environment().authentication.loginEndpoint
var privateEndpoints = !empty(privateEndpointSubnetResourceId) && !empty(privateDnsZoneResourceId) ? [
  {
    subnetResourceId: privateEndpointSubnetResourceId
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          privateDnsZoneResourceId: privateDnsZoneResourceId
        }
      ]
    }
  }
] : []
var basicPublishingCredentialsPolicies = disableBasicPublishingCredentials ? [
  {
    name: 'ftp'
    allow: false
  }
  {
    name: 'scm'
    allow: false
  }
] : []
var graphAuthAppSettings = union(
  {
    EntraId__UseManagedIdentity: '${graphUseManagedIdentity}'
  },
  graphUseManagedIdentity && !empty(identityClientId) ? {
    AZURE_CLIENT_ID: identityClientId
  } : {}
)
var graphCredentialAppSettings = !graphUseManagedIdentity ? union(
  !empty(graphTenantId) ? {
    EntraId__TenantId: graphTenantId
  } : {},
  !empty(graphClientId) ? {
    EntraId__ClientId: graphClientId
  } : {},
  !empty(graphClientSecret) ? {
    EntraId__ClientSecret: graphClientSecret
  } : {}
) : {}
var authAllowedAudiences = !empty(mcpAuthClientId) ? [
  mcpAuthClientId
  'api://${mcpAuthClientId}'
] : []
var directClientAuthorizationPolicy = !empty(allowedClientApplicationIds) ? {
  defaultAuthorizationPolicy: {
    allowedApplications: allowedClientApplicationIds
  }
  jwtClaimChecks: {
    allowedClientApplications: allowedClientApplicationIds
  }
} : {}
var authSettingV2Configuration = !empty(mcpAuthTenantId) && !empty(mcpAuthClientId) ? {
  platform: {
    enabled: true
  }
  globalValidation: {
    requireAuthentication: true
    unauthenticatedClientAction: 'Return401'
  }
  httpSettings: {
    requireHttps: true
  }
  login: {
    tokenStore: {
      enabled: false
    }
  }
  identityProviders: {
    azureActiveDirectory: {
      enabled: true
      registration: {
        clientId: mcpAuthClientId
        openIdIssuer: '${loginEndpoint}${mcpAuthTenantId}/v2.0'
      }
      validation: union({
        allowedAudiences: authAllowedAudiences
      }, directClientAuthorizationPolicy)
    }
  }
} : {}

// Create base application settings
var baseAppSettings = {
  // Only include required credential settings unconditionally
  AzureWebJobsStorage__credential: 'managedidentity'
  AzureWebJobsStorage__clientId: identityClientId
  
  // Application Insights settings are always included
  APPLICATIONINSIGHTS_AUTHENTICATION_STRING: applicationInsightsIdentity
  APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights!.properties.ConnectionString
}

// Dynamically build storage endpoint settings based on feature flags
var blobSettings = enableBlob ? { AzureWebJobsStorage__blobServiceUri: stg.properties.primaryEndpoints.blob } : {}
var queueSettings = enableQueue ? { AzureWebJobsStorage__queueServiceUri: stg.properties.primaryEndpoints.queue } : {}
var tableSettings = enableTable ? { AzureWebJobsStorage__tableServiceUri: stg.properties.primaryEndpoints.table } : {}
var fileSettings = enableFile ? { AzureWebJobsStorage__fileServiceUri: stg.properties.primaryEndpoints.file } : {}

// Merge all app settings
var allAppSettings = union(
  appSettings,
  blobSettings,
  queueSettings,
  tableSettings,
  fileSettings,
  baseAppSettings
)

resource stg 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

// Create a Flex Consumption Function App to host the MCP server
module mcp 'br/public:avm/res/web/site:0.15.1' = {
  name: '${serviceName}-flex-consumption'
  params: {
    kind: kind
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': azdServiceName })
    serverFarmResourceId: appServicePlanId
    managedIdentities: {
      systemAssigned: identityType == 'SystemAssigned'
      userAssignedResourceIds: [
        '${identityId}'
      ]
    }
    basicPublishingCredentialsPolicies: basicPublishingCredentialsPolicies
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${stg.properties.primaryEndpoints.blob}${deploymentStorageContainerName}'
          authentication: {
            type: identityType == 'SystemAssigned' ? 'SystemAssignedIdentity' : 'UserAssignedIdentity'
            userAssignedIdentityResourceId: identityType == 'UserAssigned' ? identityId : '' 
          }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: instanceMemoryMB
        maximumInstanceCount: maximumInstanceCount
      }
      runtime: {
        name: runtimeName
        version: runtimeVersion
      }
    }
    siteConfig: {
      alwaysOn: false
    }
    clientAffinityEnabled: false
    privateEndpoints: privateEndpoints
    publicNetworkAccess: publicNetworkAccess
    authSettingV2Configuration: authSettingV2Configuration
    virtualNetworkSubnetId: !empty(virtualNetworkSubnetId) ? virtualNetworkSubnetId : null
    appSettingsKeyValuePairs: union(allAppSettings, {
      UseHttp: true
    }, graphAuthAppSettings, graphCredentialAppSettings)
  }
}

output resourceId string = mcp.outputs.resourceId
output name string = mcp.outputs.name
// Ensure output is always string, handle potential null from module output if SystemAssigned is not used
output principalId string = identityType == 'SystemAssigned' ? mcp.outputs.?systemAssignedMIPrincipalId ?? '' : ''
output fqdn string = mcp.outputs.defaultHostname
