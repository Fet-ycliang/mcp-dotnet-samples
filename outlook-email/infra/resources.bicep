extension microsoftGraphV1

@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Deterministic resource naming stem, for example fet-outlook-email-bst.')
param resourceNameStem string

@description('Existing Azure Container Registry name to reuse for azd remote builds and ACA image pulls. Defaults to fetimageacr.')
param existingContainerRegistryName string = 'fetimageacr'

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

@description('Optional legacy fallback. Existing Entra tenant ID for the shared MCP OAuth resource application. Prefer directMcp* for the direct path and apimResource* for the APIM facade.')
param existingMcpOauthTenantId string = ''

@description('Optional legacy fallback. Existing Entra client/application ID for the shared MCP OAuth resource application. Prefer directMcp* for the direct path and apimResource* for the APIM facade.')
param existingMcpOauthClientId string = ''

@description('Optional legacy fallback. Existing Application ID URI for the shared MCP OAuth resource application. Prefer directMcpApplicationIdUri or apimResourceApplicationIdUri.')
param mcpOauthApplicationIdUri string = ''

@secure()
@description('Optional legacy fallback. Client secret or Key Vault reference string that must stay mapped to the ACA secret name mcp-oauth-client-secret. Prefer directMcpClientSecret.')
param mcpOauthClientSecret string = ''

@description('Optional. Existing Entra tenant ID for the direct MCP resource application that protects the Function App / ACA direct path.')
param directMcpTenantId string = ''

@description('Optional. Existing Entra client/application ID for the direct MCP resource application that protects the Function App / ACA direct path.')
param directMcpClientId string = ''

@description('Optional. Existing Application ID URI for the direct MCP resource application. Leave empty to derive api://<directMcpClientId>.')
param directMcpApplicationIdUri string = ''

@secure()
@description('Optional. Client secret or Key Vault reference string for the direct MCP resource application. This must remain mapped to the ACA secret name mcp-oauth-client-secret.')
param directMcpClientSecret string = ''

@description('Optional. Semicolon-separated Entra client/application IDs allowed to call the Function App private endpoint directly with MCP OAuth tokens.')
param directAllowedClientApplicationsCsv string = ''

@description('Optional. Existing Entra tenant ID for the APIM MCP resource application. When paired with apimResourceClientId, deployment reuses that app instead of creating a new APIM MCP resource app.')
param apimResourceTenantId string = ''

@description('Optional. Existing Entra client/application ID for the APIM MCP resource application. When paired with apimResourceTenantId, deployment reuses that app instead of creating a new APIM MCP resource app.')
param apimResourceClientId string = ''

@description('Optional. Existing Application ID URI for the APIM MCP resource application. Leave empty to derive api://<apimResourceClientId> when reusing an existing app.')
param apimResourceApplicationIdUri string = ''

@description('Optional. Existing Entra client/application ID for the Claude caller public client app used by the APIM OAuth register stub. Required when the APIM OAuth facade is deployed.')
param mcpClaudeClientId string = ''

@description('Optional. Semicolon-separated Entra client/application IDs allowed to call the APIM retained MCP path. MCP_CLAUDE_CLIENT_ID is always included automatically.')
param apimAllowedClientApplicationsCsv string = ''

@description('Optional. Semicolon-separated exact redirect URIs allowed for the Claude public client on the APIM OAuth facade. Defaults to http://localhost.')
param mcpClaudeRedirectUrisCsv string = 'http://localhost'


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

@description('Whether to deploy the sample Key Vault used for Key Vault referenced secrets.')
param deployKeyVault bool = false

@description('Optional explicit Key Vault name. Leave empty to use the standard derived naming pattern.')
param keyVaultNameOverride string = ''

@allowed([
  'Enabled'
  'Disabled'
])
@description('Public network access mode for the sample Key Vault. Keep Enabled while callers are still migrating to the private endpoint.')
param keyVaultPublicNetworkAccess string = 'Enabled'

@description('Whether to create a private endpoint for the sample Key Vault. Requires VNet + private endpoint subnet planning.')
param deployKeyVaultPrivateEndpoint bool = false

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

@description('Optional. Existing AcrPull role assignment name/GUID to adopt when reusing a shared ACR that already granted the ACA user-assigned identity pull access.')
param existingContainerRegistryAcrPullRoleAssignmentName string = ''

@maxLength(50)
@description('Optional explicit API Management service name. Must use a valid APIM service name and is ignored when deployApim is false. Leave empty to use the standard derived APIM naming pattern.')
param apimNameOverride string = ''

@description('Whether to deploy API Management in internal virtual network mode. Requires an existing VNet, an APIM subnet, and private DNS planning.')
param apimInternalVirtualNetwork bool = false

@description('Optional existing subnet name for APIM when apimInternalVirtualNetwork is true. The subnet must already exist, have no delegation, and include the required NSG rules.')
param apimSubnetName string = ''

@description('Optional. Existing APIM private DNS virtual network link name to adopt when the private zones are already linked to the target VNet.')
param apimPrivateDnsVirtualNetworkLinkName string = ''

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
var containerAppsEnvironmentName = '${abbrs.appManagedEnvironments}${normalizedStem}'
var containerAppName = !empty(apimBackendContainerAppName) ? apimBackendContainerAppName : '${abbrs.appContainerApps}${normalizedStem}'
var keyVaultName = !empty(keyVaultNameOverride) ? keyVaultNameOverride : take('${abbrs.keyVaultVaults}${normalizedStem}', 24)
var deploymentStorageContainerName = 'app-package-${normalizedStem}'
var allowedSenders = empty(allowedSendersCsv) ? [] : split(allowedSendersCsv, ';')
var allowedReplyTo = empty(allowedReplyToCsv) ? [] : split(allowedReplyToCsv, ';')
var directAllowedClientApplications = empty(directAllowedClientApplicationsCsv) ? [] : filter(map(split(directAllowedClientApplicationsCsv, ';'), appId => trim(appId)), appId => !empty(appId))
var useExistingContainerApp = !empty(apimBackendContainerAppName) || mcpOutlookEmailExists
var useExistingVirtualNetwork = vnetEnabled && !empty(existingVirtualNetworkName)
var deployApimFacade = deployApim && deployApimMcpApi
var configuredDirectMcpTenantId = !empty(directMcpTenantId) ? directMcpTenantId : existingMcpOauthTenantId
var configuredDirectMcpClientId = !empty(directMcpClientId) ? directMcpClientId : existingMcpOauthClientId
var configuredLegacySharedMcpApplicationIdUri = !empty(mcpOauthApplicationIdUri) ? mcpOauthApplicationIdUri : (!empty(existingMcpOauthClientId) ? 'api://${existingMcpOauthClientId}' : '')
var effectiveDirectMcpTenantId = configuredDirectMcpTenantId
var effectiveDirectMcpClientId = configuredDirectMcpClientId
var effectiveDirectMcpApplicationIdUri = !empty(directMcpApplicationIdUri) ? directMcpApplicationIdUri : (!empty(directMcpClientId) ? 'api://${directMcpClientId}' : configuredLegacySharedMcpApplicationIdUri)
var effectiveDirectMcpClientSecret = !empty(directMcpClientSecret) ? directMcpClientSecret : (!deployApimFacade ? mcpOauthClientSecret : '')
var configuredApimResourceTenantId = apimResourceTenantId
var configuredApimResourceClientId = apimResourceClientId
var configuredApimResourceApplicationIdUri = !empty(apimResourceApplicationIdUri) ? apimResourceApplicationIdUri : (!empty(apimResourceClientId) ? 'api://${apimResourceClientId}' : '')
var reuseExistingApimResourceApp = !empty(configuredApimResourceTenantId) && !empty(configuredApimResourceClientId)
var virtualNetworkName = useExistingVirtualNetwork ? existingVirtualNetworkName : '${abbrs.networkVirtualNetworks}${normalizedStem}'
var effectiveIntegrationSubnetName = !empty(integrationSubnetName) ? integrationSubnetName : 'app'
var effectivePrivateEndpointSubnetName = !empty(privateEndpointSubnetName) ? privateEndpointSubnetName : 'private-endpoints-subnet'
var canDeployPrivateEndpoints = vnetEnabled && (!useExistingVirtualNetwork || !empty(privateEndpointSubnetName))
var functionAppPrivateDnsZoneName = 'privatelink.azurewebsites.net'
var useSharedPrivateDnsZones = !empty(privateDnsZoneResourceGroupName)
var deployManagedKeyVaultPrivateEndpoint = deployKeyVault && deployKeyVaultPrivateEndpoint && canDeployPrivateEndpoints
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
var apimMcpResourceAppUniqueName = 'mcp-${normalizedStem}-apim'
var apimMcpResourceAppDisplayName = 'MCP-${normalizedStem}-APIM'
var functionAppDnsLinkName = '${functionAppName}-sites-link'
var userAssignedIdentityResourceId = resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentityName)
var generatedApimResourceApplicationIdUri = !empty(apimResourceApplicationIdUri) ? apimResourceApplicationIdUri : 'api://${apimMcpResourceAppUniqueName}'
var effectiveApimResourceTenantId = reuseExistingApimResourceApp ? configuredApimResourceTenantId : (deployApimFacade ? mcpEntraApp!.outputs.mcpAppTenantId : '')
var effectiveApimResourceClientId = reuseExistingApimResourceApp ? configuredApimResourceClientId : (deployApimFacade ? mcpEntraApp!.outputs.mcpAppId : '')
var effectiveApimResourceApplicationIdUri = reuseExistingApimResourceApp ? configuredApimResourceApplicationIdUri : (deployApimFacade ? mcpEntraApp!.outputs.mcpAppIdUri : '')
var effectiveMcpClaudeClientId = mcpClaudeClientId
var effectiveDirectAllowedClientApplications = deployApimFacade && !empty(directAllowedClientApplications) ? concat(directAllowedClientApplications, [mcpApimGatewayIdentity!.outputs.clientId]) : directAllowedClientApplications
var directAllowedClientApplicationEnvVars = [for (clientAppId, i) in directAllowedClientApplications: {
  name: 'McpAuth__AllowedCallerAppIds__${i}'
  value: clientAppId
}]
var apimGatewayAllowedClientApplicationEnvVars = deployApimFacade && !empty(directAllowedClientApplications) ? [
  {
    name: 'McpAuth__AllowedCallerAppIds__${length(directAllowedClientApplications)}'
    value: mcpApimGatewayIdentity!.outputs.clientId
  }
] : []
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
var directMcpClientSecretIsKeyVaultReference = !empty(effectiveDirectMcpClientSecret) && startsWith(effectiveDirectMcpClientSecret, '@Microsoft.KeyVault(') && contains(effectiveDirectMcpClientSecret, 'SecretUri=')
var directMcpClientSecretKeyVaultUrl = directMcpClientSecretIsKeyVaultReference ? replace(replace(effectiveDirectMcpClientSecret, '@Microsoft.KeyVault(SecretUri=', ''), ')', '') : ''
var graphContainerAppSecrets = !graphUseManagedIdentity && !empty(entraClientSecret) ? [
  entraClientSecretIsKeyVaultReference ? {
    name: 'graph-client-secret'
    identity: userAssignedIdentityResourceId
    keyVaultUrl: entraClientSecretKeyVaultUrl
  } : {
    name: 'graph-client-secret'
    value: entraClientSecret
  }
] : []
var directMcpContainerAppSecrets = !empty(effectiveDirectMcpClientSecret) ? [
  directMcpClientSecretIsKeyVaultReference ? {
    name: 'mcp-oauth-client-secret'
    identity: userAssignedIdentityResourceId
    keyVaultUrl: directMcpClientSecretKeyVaultUrl
  } : {
    name: 'mcp-oauth-client-secret'
    value: effectiveDirectMcpClientSecret
  }
] : []
var containerAppSecrets = concat(graphContainerAppSecrets, directMcpContainerAppSecrets)
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
var directMcpAuthEnvVars = !empty(effectiveDirectMcpTenantId) && !empty(effectiveDirectMcpClientId) ? concat(
  [
    {
      name: 'McpAuth__Enabled'
      value: 'True'
    }
    {
      name: 'McpAuth__TrustEasyAuthHeaders'
      value: 'True'
    }
    {
      name: 'McpAuth__TenantId'
      value: effectiveDirectMcpTenantId
    }
    {
      name: 'McpAuth__ClientId'
      value: effectiveDirectMcpClientId
    }
  ],
  directAllowedClientApplicationEnvVars,
  apimGatewayAllowedClientApplicationEnvVars
) : []

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

var applicationInsightsId = resourceId('Microsoft.Insights/components', applicationInsightsName)
var applicationInsightsReference = reference(applicationInsightsId, '2020-02-02', 'Full')

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

resource existingContainerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: existingContainerRegistryName
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
    appInsightsId: applicationInsightsId
    appInsightsInstrumentationKey: applicationInsightsReference.properties.InstrumentationKey
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
    existingVirtualNetworkLinkName: apimPrivateDnsVirtualNetworkLinkName
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
    existingVirtualNetworkLinkName: apimPrivateDnsVirtualNetworkLinkName
    tags: tags
  }
}

// APIM MCP resource app is separate from the direct Function / ACA resource app.
module mcpEntraApp './modules/mcp-entra-app.bicep' = if (deployApimFacade && !reuseExistingApimResourceApp) {
  name: 'mcpEntraApp'
  params: {
    mcpAppUniqueName: apimMcpResourceAppUniqueName
    mcpAppDisplayName: apimMcpResourceAppDisplayName
    mcpAppIdentifierUri: generatedApimResourceApplicationIdUri
  }
}

resource directMcpServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' existing = if (deployApimFacade && !empty(effectiveDirectMcpClientId)) {
  appId: effectiveDirectMcpClientId
}

resource apimGatewayServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' existing = if (deployApimFacade) {
  appId: mcpApimGatewayIdentity!.outputs.clientId
}

var directMcpApplicationRoleId = deployApimFacade && !empty(effectiveDirectMcpClientId) ? first(filter(directMcpServicePrincipal!.appRoles, role => role.value == 'access_as_application'))!.id : ''

resource apimGatewayAppRoleAssignment 'Microsoft.Graph/appRoleAssignedTo@v1.0' = if (deployApimFacade && !empty(effectiveDirectMcpClientId)) {
  resourceId: directMcpServicePrincipal!.id
  appRoleId: directMcpApplicationRoleId
  principalId: apimGatewayServicePrincipal!.id
}

// MCP server API endpoints
module mcpApiModule './modules/mcp-api.bicep' = if (deployApimFacade) {
  name: 'mcpApiModule'
  params: {
    apimServiceName: apimService!.outputs.name
    functionAppName: functionAppName
    backendUrl: 'https://${mcpOutlookEmail.properties.configuration.ingress.fqdn}/'
    mcpAppId: effectiveApimResourceClientId
    mcpAppIdUri: effectiveApimResourceApplicationIdUri
    mcpAppTenantId: effectiveApimResourceTenantId
    backendMcpAppId: effectiveDirectMcpClientId
    backendMcpAppIdUri: effectiveDirectMcpApplicationIdUri
    mcpClaudeClientId: effectiveMcpClaudeClientId
    apimAllowedClientApplicationsCsv: apimAllowedClientApplicationsCsv
    mcpClaudeRedirectUrisCsv: mcpClaudeRedirectUrisCsv
    backendManagedIdentityClientId: mcpApimGatewayIdentity!.outputs.clientId
  }
  dependsOn: [
    apimGatewayAppRoleAssignment
  ]
}

resource existingApimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = if (deployApimFacade) {
  name: apiManagementName
}

resource existingApimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' existing = if (deployApimFacade) {
  parent: existingApimService
  name: 'apim-logger'
}

resource existingMcpApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' existing = if (deployApimFacade) {
  parent: existingApimService
  name: 'mcp'
}

resource mcpApiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2023-05-01-preview' = if (deployApimFacade) {
  parent: existingMcpApi
  name: 'applicationinsights'
  properties: {
    loggerId: existingApimLogger.id
    alwaysLog: 'allErrors'
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 20
    }
    frontend: {
      request: {
        headers: [
          'User-Agent'
        ]
        body: {
          bytes: 0
        }
      }
      response: {
        headers: [
          'WWW-Authenticate'
        ]
        body: {
          bytes: 0
        }
      }
    }
    backend: {
      request: {
        headers: []
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    httpCorrelationProtocol: 'W3C'
    logClientIp: false
  }
  dependsOn: [
    apimService
    mcpApiModule
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
    mcpAuthTenantId: effectiveDirectMcpTenantId
    mcpAuthClientId: effectiveDirectMcpClientId
    mcpAuthApplicationIdUri: effectiveDirectMcpApplicationIdUri
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

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = if (deployKeyVault) {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    publicNetworkAccess: keyVaultPublicNetworkAccess
    softDeleteRetentionInDays: 90
    accessPolicies: []
    networkAcls: keyVaultPublicNetworkAccess == 'Disabled' ? {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    } : null
  }
}

resource keyVaultSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployKeyVault) {
  name: guid(keyVault.id, userAssignedIdentityResourceId, 'keyvault-secrets-user')
  scope: keyVault
  properties: {
    principalId: mcpOutlookEmailIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
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

module keyVaultPrivateEndpoint './modules/keyvault-privateendpoint.bicep' = if (deployManagedKeyVaultPrivateEndpoint) {
  name: 'keyVaultPrivateEndpoint'
  params: {
    location: location
    tags: tags
    virtualNetworkName: virtualNetworkName
    subnetName: effectivePrivateEndpointSubnetName
    keyVaultName: keyVault.name
    privateDnsZoneResourceGroupName: privateDnsZoneResourceGroupName
  }
}

// Reuse the shared ACR for azd remote builds and ACA image pulls.
// Keep AcrPull enforced even on retained Container App paths so existing apps do not drift from the shared ACR contract.
resource existingContainerRegistryAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: !empty(existingContainerRegistryAcrPullRoleAssignmentName)
    ? existingContainerRegistryAcrPullRoleAssignmentName
    : guid(existingContainerRegistry.id, userAssignedIdentityResourceId, 'acrpull')
  scope: existingContainerRegistry
  properties: {
    principalId: mcpOutlookEmailIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
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
var managedContainerAppIngressTransport = useExistingContainerApp && !empty(mcpOutlookEmailFetchLatestImage.outputs.ingressTransport)
  ? mcpOutlookEmailFetchLatestImage.outputs.ingressTransport
  : 'auto'

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
          server: existingContainerRegistry.properties.loginServer
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
            directMcpAuthEnvVars,
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

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = existingContainerRegistry.properties.loginServer
output AZURE_RESOURCE_KEY_VAULT_ID string = deployKeyVault ? keyVault.id : ''
output AZURE_RESOURCE_KEY_VAULT_NAME string = deployKeyVault ? keyVault.name : ''
output AZURE_RESOURCE_KEY_VAULT_URI string = deployKeyVault ? keyVault!.properties.vaultUri : ''

output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_ID string = mcpOutlookEmail.id
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_NAME string = mcpOutlookEmail.name
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN string = mcpOutlookEmail.properties.configuration.ingress.fqdn

output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_ID string = deployApim ? apimService!.outputs.id : ''
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_NAME string = deployApim ? apimService!.outputs.name : ''
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_FQDN string = deployApim ? replace(apimService!.outputs.gatewayUrl, 'https://', '') : ''
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_APIM_BACKEND_FQDN string = deployApimFacade ? mcpOutlookEmail.properties.configuration.ingress.fqdn : ''
