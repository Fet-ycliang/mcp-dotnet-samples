extension microsoftGraphV1

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

@description('Optional. Semicolon-separated Entra client/application IDs allowed to call the Function App private endpoint directly with MCP OAuth tokens.')
param directAllowedClientApplicationsCsv string = ''

@description('Optional. Existing VNet name to reuse when vnetEnabled is true. Leave empty to create a new VNet.')
param existingVirtualNetworkName string = ''

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

@description('Optional. Existing Container App name to reuse as the azd deployment target and APIM backend. Leave empty to let the template create and manage a new Container App.')
param apimBackendContainerAppName string = ''

@maxLength(50)
@description('Optional explicit API Management service name. Must use a valid APIM service name and is ignored when deployApim is false. Leave empty to use the standard derived APIM naming pattern.')
param apimNameOverride string = ''

@description('Whether to deploy API Management in internal virtual network mode. Requires an existing VNet, an APIM subnet, and private DNS planning.')
param apimInternalVirtualNetwork bool = false

@description('Optional existing subnet name for APIM when apimInternalVirtualNetwork is true. The subnet must already exist, have no delegation, and include the required NSG rules.')
param apimSubnetName string = ''

@description('Optional. Address prefix to update the existing APIM subnet inside an existing VNet when deploying APIM in internal mode.')
param apimSubnetAddressPrefix string = ''

@description('Optional. Route table resource ID to attach when updating the APIM subnet inside an existing VNet.')
param apimSubnetRouteTableResourceId string = ''

@description('Optional. Network security group resource ID to attach when updating the APIM subnet inside an existing VNet.')
param apimSubnetNetworkSecurityGroupResourceId string = ''

@description('Whether to create a private endpoint for the Function App and disable public network access on the app.')
param deployFunctionAppPrivateEndpoint bool = false

param azdServiceName string

var abbrs = loadJsonContent('./abbreviations.json')
var normalizedStem = toLower(resourceNameStem)
var compactStem = take(replace(normalizedStem, '-', ''), 22)
var functionAppName = '${abbrs.webSitesFunctions}${normalizedStem}'
var containerRegistryName = take('${abbrs.containerRegistryRegistries}${compactStem}acr', 50)
var containerAppsEnvironmentName = '${abbrs.appManagedEnvironments}${normalizedStem}'
var containerAppName = !empty(apimBackendContainerAppName) ? apimBackendContainerAppName : '${abbrs.appContainerApps}${normalizedStem}'
var deploymentStorageContainerName = 'app-package-${normalizedStem}'
var allowedSenders = empty(allowedSendersCsv) ? [] : split(allowedSendersCsv, ';')
var allowedReplyTo = empty(allowedReplyToCsv) ? [] : split(allowedReplyToCsv, ';')
var directAllowedClientApplications = empty(directAllowedClientApplicationsCsv) ? [] : filter(map(split(directAllowedClientApplicationsCsv, ';'), appId => trim(appId)), appId => !empty(appId))
var useExistingContainerApp = !empty(apimBackendContainerAppName) || mcpOutlookEmailExists
var useExistingVirtualNetwork = vnetEnabled && !empty(existingVirtualNetworkName)
var deployApimFacade = deployApim && deployApimMcpApi
var reuseExistingMcpOauthApp = !empty(existingMcpOauthTenantId) && !empty(existingMcpOauthClientId)
var virtualNetworkName = useExistingVirtualNetwork ? existingVirtualNetworkName : '${abbrs.networkVirtualNetworks}${normalizedStem}'
var effectiveIntegrationSubnetName = !empty(integrationSubnetName) ? integrationSubnetName : 'app'
var effectivePrivateEndpointSubnetName = !empty(privateEndpointSubnetName) ? privateEndpointSubnetName : 'private-endpoints-subnet'
var canDeployPrivateEndpoints = vnetEnabled && (!useExistingVirtualNetwork || !empty(privateEndpointSubnetName))
var functionAppPrivateDnsZoneName = 'privatelink.azurewebsites.net'
var useSharedPrivateDnsZones = !empty(privateDnsZoneResourceGroupName)
var deployApimInternal = deployApim && apimInternalVirtualNetwork
var manageExistingApimSubnet = useExistingVirtualNetwork && deployApimInternal && !empty(apimSubnetName) && !empty(apimSubnetAddressPrefix)
var managedFunctionAppPrivateDnsZoneResourceId = deployFunctionAppPrivateEndpoint && canDeployPrivateEndpoints && !useSharedPrivateDnsZones ? functionAppPrivateDnsZone!.outputs.resourceId : ''
var logAnalyticsName = '${abbrs.operationalInsightsWorkspaces}${normalizedStem}'
var applicationInsightsName = '${abbrs.insightsComponents}${normalizedStem}'
var applicationInsightsDashboardName = '${abbrs.portalDashboards}${normalizedStem}'
var userAssignedIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}${normalizedStem}'
var apimGatewayIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}${normalizedStem}-apim'
var apiManagementName = !empty(apimNameOverride) ? apimNameOverride : '${abbrs.apiManagementService}${normalizedStem}'
var appServicePlanName = '${abbrs.webServerFarms}${normalizedStem}'
var storageAccountName = '${abbrs.storageStorageAccounts}${compactStem}'
var mcpEntraAppUniqueName = 'mcp-${normalizedStem}'
var mcpEntraAppDisplayName = 'MCP-${normalizedStem}'
var functionAppDnsLinkName = '${functionAppName}-sites-link'
var userAssignedIdentityResourceId = resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentityName)
var effectiveMcpOauthTenantId = reuseExistingMcpOauthApp ? existingMcpOauthTenantId : mcpEntraApp!.outputs.mcpAppTenantId
var effectiveMcpOauthClientId = reuseExistingMcpOauthApp ? existingMcpOauthClientId : mcpEntraApp!.outputs.mcpAppId
var effectiveDirectAllowedClientApplications = deployApimFacade && !empty(directAllowedClientApplications) ? concat(directAllowedClientApplications, [mcpApimGatewayIdentity!.outputs.clientId]) : directAllowedClientApplications
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
var allowedSenderEnvVars = [for appSetting in items(allowedSenderAppSettings): {
  name: appSetting.key
  value: string(appSetting.value)
}]
var allowedReplyToEnvVars = [for appSetting in items(allowedReplyToAppSettings): {
  name: appSetting.key
  value: string(appSetting.value)
}]
var entraClientSecretIsKeyVaultReference = !empty(entraClientSecret) && startsWith(entraClientSecret, '@Microsoft.KeyVault(') && contains(entraClientSecret, 'SecretUri=')
var entraClientSecretKeyVaultUrl = entraClientSecretIsKeyVaultReference ? replace(replace(entraClientSecret, '@Microsoft.KeyVault(SecretUri=', ''), ')', '') : ''
var containerAppSecrets = !graphUseManagedIdentity && !empty(entraClientSecret) ? [
  entraClientSecretIsKeyVaultReference ? {
    name: 'graph-client-secret'
    identity: userAssignedIdentityResourceId
    keyVaultUrl: entraClientSecretKeyVaultUrl
  } : {
    name: 'graph-client-secret'
    value: entraClientSecret
  }
] : []
var graphAuthEnvVars = graphUseManagedIdentity ? [
  {
    name: 'EntraId__UseManagedIdentity'
    value: 'true'
  }
  {
    name: 'AZURE_CLIENT_ID'
    value: mcpOutlookEmailIdentity.outputs.clientId
  }
] : concat(
  [
    {
      name: 'EntraId__UseManagedIdentity'
      value: 'false'
    }
  ],
  !empty(entraTenantId) ? [
    {
      name: 'EntraId__TenantId'
      value: entraTenantId
    }
  ] : [],
  !empty(entraClientId) ? [
    {
      name: 'EntraId__ClientId'
      value: entraClientId
    }
  ] : [],
  !empty(entraClientSecret) ? [
    {
      name: 'EntraId__ClientSecret'
      secretRef: 'graph-client-secret'
    }
  ] : []
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

module mcpApimGatewayIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = if (deployApimFacade) {
  name: 'mcpApimGatewayIdentity'
  params: {
    name: apimGatewayIdentityName
    location: location
    tags: tags
  }
}

resource existingVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = if (useExistingVirtualNetwork) {
  name: virtualNetworkName
}

resource sharedFunctionAppPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = if (useSharedPrivateDnsZones && deployFunctionAppPrivateEndpoint && canDeployPrivateEndpoints) {
  name: functionAppPrivateDnsZoneName
  scope: resourceGroup(privateDnsZoneResourceGroupName)
}

resource existingVirtualNetworkIntegrationSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (useExistingVirtualNetwork && !empty(integrationSubnetAddressPrefix) && !empty(effectiveIntegrationSubnetName)) {
  name: effectiveIntegrationSubnetName
  parent: existingVirtualNetwork
  properties: {
    addressPrefix: integrationSubnetAddressPrefix
    delegations: [
      {
        name: 'flexConsumptionDelegation'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
    routeTable: !empty(integrationSubnetRouteTableResourceId) ? {
      id: integrationSubnetRouteTableResourceId
    } : null
    networkSecurityGroup: !empty(integrationSubnetNetworkSecurityGroupResourceId) ? {
      id: integrationSubnetNetworkSecurityGroupResourceId
    } : null
  }
}

resource existingVirtualNetworkApimSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (manageExistingApimSubnet) {
  name: apimSubnetName
  parent: existingVirtualNetwork
  properties: {
    addressPrefix: apimSubnetAddressPrefix
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    routeTable: !empty(apimSubnetRouteTableResourceId) ? {
      id: apimSubnetRouteTableResourceId
    } : null
    networkSecurityGroup: !empty(apimSubnetNetworkSecurityGroupResourceId) ? {
      id: apimSubnetNetworkSecurityGroupResourceId
    } : null
  }
}

var existingIntegrationSubnetResourceId = !empty(effectiveIntegrationSubnetName) ? resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, effectiveIntegrationSubnetName) : ''
var existingPrivateEndpointSubnetResourceId = !empty(effectivePrivateEndpointSubnetName) ? resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, effectivePrivateEndpointSubnetName) : ''
var virtualNetworkResourceId = vnetEnabled ? (useExistingVirtualNetwork ? existingVirtualNetwork.id : serviceVirtualNetwork!.outputs.vnetResourceId) : ''
var integrationSubnetResourceId = useExistingVirtualNetwork ? existingIntegrationSubnetResourceId : (vnetEnabled ? serviceVirtualNetwork!.outputs.appSubnetID : '')
var privateEndpointSubnetResourceId = useExistingVirtualNetwork ? (canDeployPrivateEndpoints ? existingPrivateEndpointSubnetResourceId : '') : (canDeployPrivateEndpoints ? serviceVirtualNetwork!.outputs.peSubnetID : '')
var apimSubnetResourceId = deployApimInternal ? resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, apimSubnetName) : ''

// API Management
module apimService './modules/apim.bicep' = if (deployApim) {
  name: 'apimService'
  params:{
    apiManagementName: apiManagementName
    apimSku: apimSku
    apimVirtualNetworkType: deployApimInternal ? 'Internal' : 'None'
    apimSubnetResourceId: apimSubnetResourceId
    managedIdentityResourceId: deployApimFacade ? mcpApimGatewayIdentity!.outputs.resourceId : ''
  }
  dependsOn: [
    existingVirtualNetworkApimSubnet
  ]
}

module apimPrivateDns './modules/apim-private-dns.bicep' = if (deployApimInternal && !useSharedPrivateDnsZones) {
  name: 'apimPrivateDnsManaged'
  params: {
    apiManagementName: apiManagementName
    privateIpAddress: apimService!.outputs.privateIpAddress
    virtualNetworkResourceId: virtualNetworkResourceId
    tags: tags
  }
}

module apimPrivateDnsShared './modules/apim-private-dns.bicep' = if (deployApimInternal && useSharedPrivateDnsZones) {
  name: 'apimPrivateDnsShared'
  scope: resourceGroup(privateDnsZoneResourceGroupName)
  params: {
    apiManagementName: apiManagementName
    privateIpAddress: apimService!.outputs.privateIpAddress
    virtualNetworkResourceId: virtualNetworkResourceId
    tags: tags
  }
}

// MCP Entra App protects both the direct Function path and the retained APIM path.
module mcpEntraApp './modules/mcp-entra-app.bicep' = if (!reuseExistingMcpOauthApp) {
  name: 'mcpEntraApp'
  params: {
    mcpAppUniqueName: mcpEntraAppUniqueName
    mcpAppDisplayName: mcpEntraAppDisplayName
    userAssignedIdentityPrincipleId: mcpOutlookEmailIdentity.outputs.principalId
    functionAppName: functionAppName
    grantMailSendToManagedIdentity: graphUseManagedIdentity
  }
}

resource effectiveMcpOauthServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' existing = if (deployApimFacade) {
  appId: effectiveMcpOauthClientId
}

resource apimGatewayServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' existing = if (deployApimFacade) {
  appId: mcpApimGatewayIdentity!.outputs.clientId
}

var mcpApplicationRoleId = deployApimFacade ? first(filter(effectiveMcpOauthServicePrincipal!.appRoles, role => role.value == 'access_as_application'))!.id : ''

resource apimGatewayAppRoleAssignment 'Microsoft.Graph/appRoleAssignedTo@v1.0' = if (deployApimFacade) {
  resourceId: effectiveMcpOauthServicePrincipal!.id
  appRoleId: mcpApplicationRoleId
  principalId: apimGatewayServicePrincipal!.id
}

// MCP server API endpoints
module mcpApiModule './modules/mcp-api.bicep' = if (deployApimFacade) {
  name: 'mcpApiModule'
  params: {
    apimServiceName: apimService!.outputs.name
    functionAppName: functionAppName
    backendUrl: 'https://${mcpOutlookEmail.properties.configuration.ingress.fqdn}/'
    mcpAppId: effectiveMcpOauthClientId
    mcpAppTenantId: effectiveMcpOauthTenantId
    backendManagedIdentityClientId: mcpApimGatewayIdentity!.outputs.clientId
  }
  dependsOn: [
    apimGatewayAppRoleAssignment
  ]
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = {
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

// Function app
module fncapp './modules/functionapp.bicep' = {
  name: 'functionapp'
  params: {
    name: functionAppName
    location: location
    tags: tags
    azdServiceName: '${azdServiceName}-function'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.resourceId
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
    mcpAuthTenantId: effectiveMcpOauthTenantId
    mcpAuthClientId: effectiveMcpOauthClientId
    allowedClientApplicationIds: effectiveDirectAllowedClientApplications
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
    subnetName: effectivePrivateEndpointSubnetName
    resourceName: storage.outputs.name
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
    privateDnsZoneResourceGroupName: privateDnsZoneResourceGroupName
  }
}

// Container registry for azd remote builds
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = {
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
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
    ]
  }
}

module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.4.5' = if (!useExistingContainerApp) {
  name: 'container-apps-environment'
  params: {
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    name: containerAppsEnvironmentName
    location: location
    zoneRedundant: false
    tags: tags
  }
}

module mcpOutlookEmailFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'mcpOutlookEmail-fetch-image'
  params: {
    exists: useExistingContainerApp
    name: containerAppName
  }
}

var managedContainerAppEnvironmentResourceId = useExistingContainerApp
  ? mcpOutlookEmailFetchLatestImage.outputs.managedEnvironmentId
  : containerAppsEnvironment!.outputs.resourceId
var managedContainerAppImage = useExistingContainerApp && length(mcpOutlookEmailFetchLatestImage.outputs.containers) > 0
  ? mcpOutlookEmailFetchLatestImage.outputs.containers[0].image
  : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
var managedContainerAppIngressExternal = useExistingContainerApp ? mcpOutlookEmailFetchLatestImage.outputs.ingressExternal : true
var managedContainerAppIngressTransport = useExistingContainerApp ? mcpOutlookEmailFetchLatestImage.outputs.ingressTransport : 'auto'

resource mcpOutlookEmail 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: union(tags, {
    'azd-service-name': azdServiceName
  })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedContainerAppEnvironmentResourceId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: managedContainerAppIngressExternal
        targetPort: 8080
        transport: managedContainerAppIngressTransport
        allowInsecure: false
      }
      registries: [
        {
          server: containerRegistry.outputs.loginServer
          identity: userAssignedIdentityResourceId
        }
      ]
      secrets: containerAppSecrets
    }
    template: {
      containers: [
        {
          name: 'main'
          image: managedContainerAppImage
          args: [
            '--http'
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: concat(
            [
              {
                name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
                value: monitoring.outputs.applicationInsightsConnectionString
              }
              {
                name: 'FUNCTIONS_CUSTOMHANDLER_PORT'
                value: '8080'
              }
              {
                name: 'UseHttp'
                value: 'true'
              }
            ],
            graphAuthEnvVars,
            allowedSenderEnvVars,
            allowedReplyToEnvVars
          )
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_ID string = mcpOutlookEmail.id
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_NAME string = mcpOutlookEmail.name
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN string = mcpOutlookEmail.properties.configuration.ingress.fqdn

output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_ID string = deployApim ? apimService!.outputs.id : ''
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_NAME string = deployApim ? apimService!.outputs.name : ''
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_FQDN string = deployApim ? replace(apimService!.outputs.gatewayUrl, 'https://', '') : ''
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_APIM_BACKEND_FQDN string = deployApimFacade ? mcpOutlookEmail.properties.configuration.ingress.fqdn : ''
