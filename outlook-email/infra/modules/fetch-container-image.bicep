param exists bool
param name string

resource existingApp 'Microsoft.App/containerApps@2024-03-01' existing = if (exists) {
  name: name
}

output containers array = exists ? existingApp!.properties.template.containers : []
output managedEnvironmentId string = exists ? existingApp!.properties.managedEnvironmentId : ''
output ingressExternal bool = exists ? bool(existingApp!.properties.configuration.ingress.external) : false
output ingressTransport string = exists ? existingApp!.properties.configuration.ingress.transport : ''
