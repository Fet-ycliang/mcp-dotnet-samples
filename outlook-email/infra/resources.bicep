@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Deterministic resource naming stem, for example fet-outlook-email-bst.')
param resourceNameStem string

param mcpOutlookEmailExists bool

param vnetEnabled bool = true // Enable VNet by default

@description('Id of the user or app to assign application roles')
param principalId string

@description('Whether to temporarily grant deployment user RBAC for storage and monitoring troubleshooting. Keep false in production.')
param allowUserIdentityPrincipalRbac bool = false

@description('Semicolon-separated sender allowlist that will be projected to Function App settings as AllowedSenders__N.')
param allowedSendersCsv string = ''

@description('Semicolon-separated reply-to allowlist that will be projected to Function App settings as AllowedReplyTo__N.')
param allowedReplyToCsv string = ''

@description('Whether Graph auth should use managed identity. Set false to use EntraId__TenantId / EntraId__ClientId / EntraId__ClientSecret app settings.')
param graphUseManagedIdentity bool = true

@description('Optional. Graph tenant ID when using service principal credentials from Function App app settings.')
param entraTenantId string = ''

@description('Optional. Graph client ID when using service principal credentials from Function App app settings.')
param entraClientId string = ''

@secure()
@description('Optional. Graph client secret or Key Vault reference string when using service principal credentials from Function App app settings.')
param entraClientSecret string = ''

@description('Optional. Existing Entra tenant ID for the MCP OAuth resource application used by APIM token validation. When paired with existingMcpOauthClientId, deployment reuses that app instead of creating a new MCP app registration.')
param existingMcpOauthTenantId string = ''

@description('Optional. Existing Entra client/application ID for the MCP OAuth resource application used by APIM token validation. When paired with existingMcpOauthTenantId, deployment reuses that app instead of creating a new MCP app registration.')
param existingMcpOauthClientId string = ''

@description('Optional. Existing VNet name to reuse when vnetEnabled is true. Leave empty to create a new VNet.')
param existingVirtualNetworkName string = ''

@description('Optional. Resource group that hosts the existing VNet when reusing across resource groups. Leave empty to assume the same resource group as the deployment.')
param existingVirtualNetworkResourceGroupName string = ''

@description('Optional. Name of the Flex Consumption integration subnet. When reusing an existing VNet, this subnet must not contain underscores and must be delegated to Microsoft.App/environments.')
param integrationSubnetName string = ''

@description('Optional. Address prefix to create or update the integration subnet inside an existing VNet.')
param integrationSubnetAddressPrefix string = ''

@description('Optional. Existing subnet name to host private endpoints when reusing an existing VNet.')
param privateEndpointSubnetName string = ''

@description('Optional. Route table resource ID to attach when creating the integration subnet inside an existing VNet.')
param integrationSubnetRouteTableResourceId string = ''

@description('Optional. Network security group resource ID to attach when creating the integration subnet inside an existing VNet.')
param integrationSubnetNetworkSecurityGroupResourceId string = ''

@description('Optional. Resource group that hosts shared private DNS zones to reuse for private endpoints and internal APIM hostnames.')
param privateDnsZoneResourceGroupName string = ''

@description('Whether to deploy API Management and the MCP API facade.')
param deployApim bool = true

@description('API Management SKU for the APIM + OAuth MCP gateway path. Use Developer for dev/test cost control, and reassess before production.')
@allowed([
  'Developer'
  'Basic'
  'Basicv2'
  'Standard'
  'Standardv2'
  'Premium'
])
param apimSku string = 'Basicv2'

@description('Whether to configure the MCP API facade and OAuth app objects inside APIM. Set false to deploy APIM networking/private DNS first and defer OAuth later.')
param deployApimMcpApi bool = true

@maxLength(50)
@description('Optional explicit API Management service name. Must use a valid APIM service name and is ignored when deployApim is false. Leave empty to use the standard derived APIM naming pattern.')
param apimNameOverride string = ''

@description('Whether to deploy API Management in internal virtual network mode. Requires an existing VNet, an APIM subnet, and private DNS planning.')
param apimInternalVirtualNetwork bool = false

@description('Optional existing subnet name for APIM when apimInternalVirtualNetwork is true. The subnet must already exist, have no delegation, and include the required NSG rules.')
param apimSubnetName string = ''

@description('Whether to create a private endpoint for the Function App and disable public network access on the app.')
param deployFunctionAppPrivateEndpoint bool = false

@description('Whether to deploy Azure Container Apps instead of Azure Functions as the MCP server host. When true, deploys ACR + Container Apps Environment + Container App. When false (default), deploys Flex Consumption Function App.')
param deployAca bool = false

param azdServiceName string

var abbrs = loadJsonContent('./abbreviations.json')
var normalizedStem = toLower(resourceNameStem)
var compactStem = take(replace(normalizedStem, '-', ''), 22)
var functionAppName = '${abbrs.webSitesFunctions}${normalizedStem}'
var containerAppName = '${abbrs.appContainerApps}${normalizedStem}'
var containerRegistryName = '${abbrs.containerRegistryRegistries}${compactStem}'
var containerAppsEnvironmentName = '${abbrs.appManagedEnvironments}${normalizedStem}'
var deploymentStorageContainerName = 'app-package-${normalizedStem}'
var allowedSenders = empty(allowedSendersCsv) ? [] : split(allowedSendersCsv, ';')
var allowedReplyTo = empty(allowedReplyToCsv) ? [] : split(allowedReplyToCsv, ';')
var useExistingVirtualNetwork = vnetEnabled && !empty(existingVirtualNetworkName)
var effectiveVnetResourceGroupName = !empty(existingVirtualNetworkResourceGroupName) ? existingVirtualNetworkResourceGroupName : resourceGroup().name
// APIM MCP API facade is only available on the Functions path; ACA path skips the function-specific facade wiring
var deployApimFacade = !deployAca && deployApim && deployApimMcpApi
var reuseExistingMcpOauthApp = deployApimFacade && !empty(existingMcpOauthTenantId) && !empty(existingMcpOauthClientId)
var virtualNetworkName = useExistingVirtualNetwork ? existingVirtualNetworkName : '${abbrs.networkVirtualNetworks}${normalizedStem}'
var effectiveIntegrationSubnetName = !empty(integrationSubnetName) ? integrationSubnetName : 'app'
var effectivePrivateEndpointSubnetName = !empty(privateEndpointSubnetName) ? privateEndpointSubnetName : 'private-endpoints-subnet'
var canDeployPrivateEndpoints = vnetEnabled && (!useExistingVirtualNetwork || !empty(privateEndpointSubnetName))
var functionAppPrivateDnsZoneName = 'privatelink.azurewebsites.net'
var useSharedPrivateDnsZones = !empty(privateDnsZoneResourceGroupName)
var deployApimInternal = deployApim && apimInternalVirtualNetwork
var managedFunctionAppPrivateDnsZoneResourceId = deployFunctionAppPrivateEndpoint && canDeployPrivateEndpoints && !useSharedPrivateDnsZones ? functionAppPrivateDnsZone!.outputs.resourceId : ''
var logAnalyticsName = '${abbrs.operationalInsightsWorkspaces}${normalizedStem}'
var applicationInsightsName = '${abbrs.insightsComponents}${normalizedStem}'
var applicationInsightsDashboardName = '${abbrs.portalDashboards}${normalizedStem}'
var userAssignedIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}${normalizedStem}'
var apiManagementName = !empty(apimNameOverride) ? apimNameOverride : '${abbrs.apiManagementService}${normalizedStem}'
var appServicePlanName = '${abbrs.webServerFarms}${normalizedStem}'
var storageAccountName = '${abbrs.storageStorageAccounts}${compactStem}'
var mcpEntraAppUniqueName = 'mcp-${normalizedStem}'
var mcpEntraAppDisplayName = 'MCP-${normalizedStem}'
var functionAppDnsLinkName = '${functionAppName}-sites-link'
var allowedSenderAppSettings = reduce(
  allowedSenders,
  {},
  (cur, next, i) => union(cur, {
    'AllowedSenders__${i}': next
  })
)
var allowedReplyToAppSettings = reduce(
  allowedReplyTo,
  {},
  (cur, next, i) => union(cur, {
    'AllowedReplyTo__${i}': next
  })
)

// Monitor application with Azure Monitor
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: logAnalyticsName
    applicationInsightsName: applicationInsightsName
    applicationInsightsDashboardName: applicationInsightsDashboardName
    location: location
    tags: tags
  }
}

resource monitoringDashboard 'Microsoft.Portal/dashboards@2022-12-01-preview' existing = {
  name: applicationInsightsDashboardName
}

resource monitoringDashboardTags 'Microsoft.Resources/tags@2021-04-01' = {
  name: 'default'
  scope: monitoringDashboard
  properties: {
    tags: tags
  }
  dependsOn: [
    monitoring
  ]
}

// User assigned identity
module mcpOutlookEmailIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'mcpOutlookEmailIdentity'
  params: {
    name: userAssignedIdentityName
    location: location
    tags: tags
  }
}

resource existingVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = if (useExistingVirtualNetwork) {
  name: virtualNetworkName
  scope: resourceGroup(effectiveVnetResourceGroupName)
}

resource sharedFunctionAppPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = if (useSharedPrivateDnsZones && deployFunctionAppPrivateEndpoint && canDeployPrivateEndpoints) {
  name: functionAppPrivateDnsZoneName
  scope: resourceGroup(privateDnsZoneResourceGroupName)
}

// Integration subnet creation/update: always use a scoped module to handle both same-RG and cross-RG VNet scenarios
module existingVnetIntegrationSubnet './modules/integration-subnet.bicep' = if (useExistingVirtualNetwork && !empty(integrationSubnetAddressPrefix) && !empty(effectiveIntegrationSubnetName)) {
  name: 'integrationSubnet'
  scope: resourceGroup(effectiveVnetResourceGroupName)
  params: {
    vnetName: virtualNetworkName
    subnetName: effectiveIntegrationSubnetName
    addressPrefix: integrationSubnetAddressPrefix
    routeTableId: integrationSubnetRouteTableResourceId
    nsgId: integrationSubnetNetworkSecurityGroupResourceId
  }
}

var existingIntegrationSubnetResourceId = !empty(effectiveIntegrationSubnetName) ? resourceId(effectiveVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, effectiveIntegrationSubnetName) : ''
var existingPrivateEndpointSubnetResourceId = !empty(effectivePrivateEndpointSubnetName) ? resourceId(effectiveVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, effectivePrivateEndpointSubnetName) : ''
var virtualNetworkResourceId = vnetEnabled ? (useExistingVirtualNetwork ? existingVirtualNetwork.id : serviceVirtualNetwork!.outputs.vnetResourceId) : ''
var integrationSubnetResourceId = useExistingVirtualNetwork ? existingIntegrationSubnetResourceId : (vnetEnabled ? serviceVirtualNetwork!.outputs.appSubnetID : '')
var privateEndpointSubnetResourceId = useExistingVirtualNetwork ? (canDeployPrivateEndpoints ? existingPrivateEndpointSubnetResourceId : '') : (canDeployPrivateEndpoints ? serviceVirtualNetwork!.outputs.peSubnetID : '')
var apimSubnetResourceId = deployApimInternal ? resourceId(effectiveVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, apimSubnetName) : ''

// API Management
module apimService './modules/apim.bicep' = if (deployApim) {
  name: 'apimService'
  params:{
    apiManagementName: apiManagementName
    apimSku: apimSku
    apimVirtualNetworkType: deployApimInternal ? 'Internal' : 'None'
    apimSubnetResourceId: apimSubnetResourceId
  }
}

module apimPrivateDns './modules/apim-private-dns.bicep' = if (deployApimInternal && !useSharedPrivateDnsZones) {
  name: 'apimPrivateDnsManaged'
  params: {
    apiManagementName: apiManagementName
    privateIpAddress: apimService.outputs.privateIpAddress
    virtualNetworkResourceId: virtualNetworkResourceId
    tags: tags
  }
}

module apimPrivateDnsShared './modules/apim-private-dns.bicep' = if (deployApimInternal && useSharedPrivateDnsZones) {
  name: 'apimPrivateDnsShared'
  scope: resourceGroup(privateDnsZoneResourceGroupName)
  params: {
    apiManagementName: apiManagementName
    privateIpAddress: apimService.outputs.privateIpAddress
    virtualNetworkResourceId: virtualNetworkResourceId
    tags: tags
  }
}

// MCP Entra App is only required for the APIM + OAuth path.
module mcpEntraApp './modules/mcp-entra-app.bicep' = if (deployApimFacade && !reuseExistingMcpOauthApp) {
  name: 'mcpEntraApp'
  params: {
    mcpAppUniqueName: mcpEntraAppUniqueName
    mcpAppDisplayName: mcpEntraAppDisplayName
    userAssignedIdentityPrincipleId: mcpOutlookEmailIdentity.outputs.principalId
    functionAppName: functionAppName
    grantMailSendToManagedIdentity: graphUseManagedIdentity
  }
}

// MCP server API endpoints
module mcpApiModule './modules/mcp-api.bicep' = if (deployApimFacade) {
  name: 'mcpApiModule'
  params: {
    apimServiceName: apimService.outputs.name
    functionAppName: functionAppName
    mcpAppId: reuseExistingMcpOauthApp ? existingMcpOauthClientId : mcpEntraApp.outputs.mcpAppId
    mcpAppTenantId: reuseExistingMcpOauthApp ? existingMcpOauthTenantId : mcpEntraApp.outputs.mcpAppTenantId
  }
  dependsOn: [
    fncapp
  ]
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = if (!deployAca) {
  name: 'appServicePlan'
  params: {
    name: appServicePlanName
    kind: 'FunctionApp'
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
    }
    reserved: true
    location: location
    tags: tags
  }
}

// Function app (Functions path only)
module fncapp './modules/functionapp.bicep' = if (!deployAca) {
  name: 'functionapp'
  params: {
    name: functionAppName
    location: location
    tags: tags
    azdServiceName: azdServiceName
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan!.outputs.resourceId
    runtimeName: 'dotnet-isolated'
    runtimeVersion: '10.0'
    storageAccountName: storage.outputs.name
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
    deploymentStorageContainerName: deploymentStorageContainerName
    identityId: mcpOutlookEmailIdentity.outputs.resourceId
    identityClientId: mcpOutlookEmailIdentity.outputs.clientId
    graphUseManagedIdentity: graphUseManagedIdentity
    graphTenantId: entraTenantId
    graphClientId: entraClientId
    graphClientSecret: entraClientSecret
    appSettings: union(allowedSenderAppSettings, allowedReplyToAppSettings)
    virtualNetworkSubnetId: integrationSubnetResourceId
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    privateDnsZoneResourceId: deployFunctionAppPrivateEndpoint && canDeployPrivateEndpoints ? (useSharedPrivateDnsZones ? sharedFunctionAppPrivateDnsZone.id : managedFunctionAppPrivateDnsZoneResourceId) : ''
    publicNetworkAccess: deployFunctionAppPrivateEndpoint && canDeployPrivateEndpoints ? 'Disabled' : 'Enabled'
    disableBasicPublishingCredentials: deployFunctionAppPrivateEndpoint && canDeployPrivateEndpoints
  }
}

// Backing storage for Azure Functions app
module storage 'br/public:avm/res/storage/storage-account:0.8.3' = {
  name: 'storage'
  params: {
    name: storageAccountName
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // Disable local authentication methods as per policy
    dnsEndpointType: 'Standard'
    publicNetworkAccess: canDeployPrivateEndpoints ? 'Disabled' : 'Enabled'
    networkAcls: canDeployPrivateEndpoints ? {
      defaultAction: 'Deny'
      bypass: 'None'
    } : {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    blobServices: {
      containers: [{name: deploymentStorageContainerName}]
    }
    minimumTlsVersion: 'TLS1_2'  // Enforcing TLS 1.2 for better security
    location: location
    tags: tags
  }
}

// Define the configuration object locally to pass to the modules
var storageEndpointConfig = {
  enableBlob: true  // Required for AzureWebJobsStorage, .zip deployment, Event Hubs trigger and Timer trigger checkpointing
  enableQueue: false  // Required for Durable Functions and MCP trigger
  enableTable: false  // Required for Durable Functions and OpenAI triggers and bindings
  enableFiles: false   // Not required, used in legacy scenarios
  allowUserIdentityPrincipal: allowUserIdentityPrincipalRbac   // Opt-in only for troubleshooting; keep disabled in production
}

// Virtual Network & private endpoint to blob storage
module serviceVirtualNetwork './modules/vnet.bicep' =  if (vnetEnabled && !useExistingVirtualNetwork) {
  name: 'serviceVirtualNetwork'
  params: {
    location: location
    tags: tags
    vNetName: virtualNetworkName
  }
}

module functionAppPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (deployFunctionAppPrivateEndpoint && canDeployPrivateEndpoints && !useSharedPrivateDnsZones) {
  name: 'function-app-private-dns-zone-deployment'
  params: {
    name: functionAppPrivateDnsZoneName
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        name: functionAppDnsLinkName
        virtualNetworkResourceId: virtualNetworkResourceId
        registrationEnabled: false
        location: 'global'
        tags: tags
      }
    ]
  }
}

// Consolidated Role Assignments
module rbac './modules/rbac.bicep' = {
  name: 'rbacAssignments'
  params: {
    storageAccountName: storage.outputs.name
    appInsightsName: monitoring.outputs.applicationInsightsName
    managedIdentityPrincipalId: mcpOutlookEmailIdentity.outputs.principalId
    userIdentityPrincipalId: principalId
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
    allowUserIdentityPrincipal: storageEndpointConfig.allowUserIdentityPrincipal
  }
}

module storagePrivateEndpoint './modules/storage-privateendpoint.bicep' = if (canDeployPrivateEndpoints) {
  name: 'servicePrivateEndpoint'
  params: {
    location: location
    tags: tags
    virtualNetworkName: virtualNetworkName
    vnetResourceGroupName: effectiveVnetResourceGroupName
    subnetName: effectivePrivateEndpointSubnetName
    resourceName: storage.outputs.name
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
    privateDnsZoneResourceGroupName: privateDnsZoneResourceGroupName
  }
}

// Container registry (ACA path)
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = if (deployAca) {
  name: 'registry'
  params: {
    name: containerRegistryName
    location: location
    tags: tags
    publicNetworkAccess: 'Enabled'
    roleAssignments: [
      {
        principalId: mcpOutlookEmailIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        // ACR pull role (7f951dda-4ed3-4680-a7ca-43fe172d538d)
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
    ]
  }
}

// Container apps environment (ACA path)
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.4.5' = if (deployAca) {
  name: 'container-apps-environment'
  params: {
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    name: containerAppsEnvironmentName
    location: location
    tags: tags
    zoneRedundant: false
  }
}

// Fetch existing container image on re-deploy so azd preserves the current image (ACA path)
module mcpOutlookEmailFetchLatestImage './modules/fetch-container-image.bicep' = if (deployAca) {
  name: 'mcpOutlookEmail-fetch-image'
  params: {
    exists: mcpOutlookEmailExists
    name: containerAppName
  }
}

// Azure Container App (ACA path)
module mcpOutlookEmail 'br/public:avm/res/app/container-app:0.8.0' = if (deployAca) {
  name: 'mcpOutlookEmail'
  params: {
    name: containerAppName
    ingressTargetPort: 8080
    scaleMinReplicas: 0
    scaleMaxReplicas: 10
    secrets: {
      secureList: []
    }
    containers: [
      {
        image: mcpOutlookEmailFetchLatestImage!.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: [
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: mcpOutlookEmailIdentity.outputs.clientId
          }
          // FUNCTIONS_CUSTOMHANDLER_PORT controls the HTTP port the app listens on
          {
            name: 'FUNCTIONS_CUSTOMHANDLER_PORT'
            value: '8080'
          }
          {
            name: 'EntraId__UseManagedIdentity'
            value: '${graphUseManagedIdentity}'
          }
        ]
        args: [
          '--http'
        ]
      }
    ]
    managedIdentities: {
      systemAssigned: false
      userAssignedResourceIds: [
        mcpOutlookEmailIdentity.outputs.resourceId
      ]
    }
    registries: [
      {
        server: containerRegistry!.outputs.loginServer
        identity: mcpOutlookEmailIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment!.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': azdServiceName })
  }
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = deployAca ? containerRegistry!.outputs.loginServer : ''
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_ID string = deployAca ? mcpOutlookEmail!.outputs.resourceId : fncapp!.outputs.resourceId
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_NAME string = deployAca ? mcpOutlookEmail!.outputs.name : fncapp!.outputs.name
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN string = deployAca ? mcpOutlookEmail!.outputs.fqdn : fncapp!.outputs.fqdn
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_ACA_FQDN string = deployAca ? mcpOutlookEmail!.outputs.fqdn : ''

output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_ID string = deployApim ? apimService!.outputs.id : ''
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_NAME string = deployApim ? apimService!.outputs.name : ''
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_FQDN string = deployApim ? replace(apimService!.outputs.gatewayUrl, 'https://', '') : ''
