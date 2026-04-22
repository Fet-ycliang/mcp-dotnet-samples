param exists bool
param name string

resource existingApp 'Microsoft.App/containerApps@2023-05-02-preview' existing = if (exists) {
  name: name
}

output containers array = exists ? existingApp!.properties.template.containers : []
output managedEnvironmentId string = exists ? existingApp!.properties.managedEnvironmentId : ''
output ingressExternal bool = exists ? existingApp!.properties.configuration.ingress.external : true
output ingressTransport string = exists ? existingApp!.properties.configuration.ingress.transport : 'auto'
