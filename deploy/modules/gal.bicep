param namingStructure string
param location string
param abbreviations object

param tags object = {}

resource computeGallery 'Microsoft.Compute/galleries@2021-10-01' = {
  name: replace(replace(namingStructure, '{rtype}', abbreviations['Azure Compute Gallery']), '-', '_')
  location: location
  tags: tags
}
