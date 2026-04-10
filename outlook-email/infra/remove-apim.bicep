/**
 * @description Removes an existing APIM instance (and optionally its private DNS zone VNet links)
 * using a deployment script. Run this before rebuilding APIM with a different subnet prefix.
 *
 * Usage:
 *   az deployment group create \
 *     --resource-group <rg-name> \
 *     --template-file infra/remove-apim.bicep \
 *     --parameters infra/remove-apim.parameters.json
 *
 * Prerequisites:
 *   - The managed identity supplied via userAssignedIdentityResourceId must have
 *     Contributor (or API Management Service Contributor) on the resource group.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Resource naming stem, e.g. fet-outlook-email-bst. Used to derive apimName when apimNameOverride is empty.')
param resourceNameStem string

@description('Optional. Explicit APIM service name. Overrides the apim-<resourceNameStem> default.')
@maxLength(50)
param apimNameOverride string = ''

@description('Resource ID of the user-assigned managed identity used to run the deletion script.')
param userAssignedIdentityResourceId string

@description('Location for the deployment script resource.')
param location string = resourceGroup().location

@description('Whether to also delete the APIM private DNS zone VNet links created for internal-mode APIM.')
param removeApimPrivateDnsLinks bool = false

@description('Resource ID of the virtual network whose links should be removed. Required when removeApimPrivateDnsLinks is true.')
param virtualNetworkResourceId string = ''

@description('Resource group that hosts the APIM private DNS zones. Leave empty if the DNS zones are in the same resource group.')
param privateDnsZoneResourceGroupName string = ''

// ------------------
//    VARIABLES
// ------------------

var abbrs = loadJsonContent('./abbreviations.json')
var normalizedStem = toLower(resourceNameStem)
var apimName = !empty(apimNameOverride) ? apimNameOverride : '${abbrs.apiManagementService}${normalizedStem}'
var effectiveDnsRg = empty(privateDnsZoneResourceGroupName) ? resourceGroup().name : privateDnsZoneResourceGroupName

// Derive the same VNet link name that apim-private-dns.bicep generates
var dnsLinkName = 'link-${take(uniqueString(apimName, virtualNetworkResourceId), 16)}'

var apimPrivateDnsZoneNames = [
  'azure-api.net'
  'portal.azure-api.net'
  'developer.azure-api.net'
  'management.azure-api.net'
  'scm.azure-api.net'
]

// Build a shell script that:
//   1. Deletes the APIM service (long-running; --no-wait is NOT used so the script waits)
//   2. Optionally removes VNet links from each APIM private DNS zone
var deleteApimScript = '''
set -e
echo "Deleting APIM: ${APIM_NAME} in RG: ${RESOURCE_GROUP}"
if az apim show --name "${APIM_NAME}" --resource-group "${RESOURCE_GROUP}" &>/dev/null; then
  az apim delete --name "${APIM_NAME}" --resource-group "${RESOURCE_GROUP}" --yes
  echo "APIM deleted."
else
  echo "APIM ${APIM_NAME} not found – skipping."
fi
'''

var deleteDnsLinksScript = removeApimPrivateDnsLinks && !empty(virtualNetworkResourceId) ? '''
echo "Removing APIM private DNS zone VNet links from zones: ${DNS_ZONES}"
for ZONE in ${DNS_ZONES}; do
  if az network private-dns link vnet show \
      --resource-group "${DNS_RG}" \
      --zone-name "${ZONE}" \
      --name "${LINK_NAME}" &>/dev/null; then
    az network private-dns link vnet delete \
      --resource-group "${DNS_RG}" \
      --zone-name "${ZONE}" \
      --name "${LINK_NAME}" \
      --yes
    echo "Removed VNet link from ${ZONE}"
  else
    echo "Link ${LINK_NAME} not found in ${ZONE} – skipping."
  fi
done
''' : ''

var fullScript = '${deleteApimScript}${deleteDnsLinksScript}'

// ------------------
//    RESOURCES
// ------------------

resource removeApimScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'remove-apim-${take(uniqueString(apimName, resourceGroup().id), 8)}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    azCliVersion: '2.63.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    environmentVariables: concat(
      [
        { name: 'APIM_NAME', value: apimName }
        { name: 'RESOURCE_GROUP', value: resourceGroup().name }
      ],
      removeApimPrivateDnsLinks && !empty(virtualNetworkResourceId) ? [
        { name: 'DNS_RG', value: effectiveDnsRg }
        { name: 'DNS_ZONES', value: join(apimPrivateDnsZoneNames, ' ') }
        { name: 'LINK_NAME', value: dnsLinkName }
      ] : []
    )
    scriptContent: fullScript
  }
}

// ------------------
//    OUTPUTS
// ------------------

output deletedApimName string = apimName
output scriptProvisioningState string = removeApimScript.properties.provisioningState
