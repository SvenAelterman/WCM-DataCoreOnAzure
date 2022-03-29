targetScope = 'subscription'

param location string

param tags object = {}
param deploymentNameStructure string = '{rtype}-${utcNow()}'

resource networkWatcherResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'NetworkWatcherRG'
  location: location
  tags: tags
}

module networkWatcher 'networkWatcher.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'networkWatcher')
  scope: networkWatcherResourceGroup
  params: {
    location: location
  }
}
