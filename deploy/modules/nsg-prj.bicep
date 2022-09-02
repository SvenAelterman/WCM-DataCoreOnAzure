/*
 * This is the Network Security Group (NSG) for a research project's default subnet.
*/

param namingStructure string
param location string
param avdSubnetRange string

var securityRules = [
  {
    name: 'Allow_RDP_From_AVD'
    properties: {
      direction: 'Inbound'
      priority: 200
      protocol: 'TCP'
      access: 'Allow'
      sourceAddressPrefix: avdSubnetRange
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
      destinationPortRange: '3389'
    }
  }
  {
    name: 'Allow_AzureUpdateDelivery'
    properties: {
      direction: 'Outbound'
      priority: 203
      protocol: 'TCP'
      access: 'Allow'
      sourceAddressPrefix: 'VirtualNetwork'
      sourcePortRange: '*'
      destinationAddressPrefix: 'AzureUpdateDelivery'
      destinationPortRange: '443'
    }
  }
  {
    name: 'Allow_AzureAD_ServiceTag'
    properties: {
      direction: 'Outbound'
      priority: 210
      protocol: 'TCP'
      access: 'Allow'
      sourceAddressPrefix: 'VirtualNetwork'
      sourcePortRange: '*'
      destinationAddressPrefix: 'AzureActiveDirectory'
      destinationPortRanges: [
        '80'
        '443'
      ]
    }
  }
  {
    name: 'Allow_MDC'
    properties: {
      direction: 'Outbound'
      priority: 220
      protocol: '*'
      access: 'Allow'
      sourceAddressPrefix: 'VirtualNetwork'
      sourcePortRange: '*'
      destinationAddressPrefix: 'AzureSecurityCenter'
      destinationPortRange: '*'
    }
  }
  {
    name: 'Allow_FrontDoor_Frontend'
    // Required for Azure AD
    properties: {
      direction: 'Outbound'
      priority: 240
      protocol: 'TCP'
      access: 'Allow'
      sourceAddressPrefix: 'VirtualNetwork'
      sourcePortRange: '*'
      destinationAddressPrefix: 'AzureFrontDoor.Frontend'
      destinationPortRanges: [
        '80'
        '443'
      ]
    }
  }
  {
    name: 'Allow_FrontDoor_FirstParty'
    // Required for Azure Update Delivery
    properties: {
      direction: 'Outbound'
      priority: 241
      protocol: 'TCP'
      access: 'Allow'
      sourceAddressPrefix: 'VirtualNetwork'
      sourcePortRange: '*'
      destinationAddressPrefix: 'AzureFrontDoor.FirstParty'
      destinationPortRanges: [
        '80'
        '443'
      ]
    }
  }
  {
    name: 'Allow_AzureAD_IPv4'
    properties: {
      direction: 'Outbound'
      priority: 211
      protocol: 'TCP'
      access: 'Allow'
      sourceAddressPrefix: 'VirtualNetwork'
      sourcePortRange: '*'
      destinationAddressPrefixes: [
        // From JSON https://www.microsoft.com/en-us/download/details.aspx?id=56519
        '20.20.32.0/27'
        '20.72.21.96/27'
        '20.190.128.0/26'
        '20.190.128.64/28'
        '20.190.128.128/27'
        '20.190.128.160/29'
        '20.190.129.0/26'
        '20.190.129.64/28'
        '20.190.129.128/27'
        '20.190.129.160/29'
        '20.190.130.0/27'
        '20.190.130.32/29'
        '20.190.131.0/27'
        '20.190.131.32/29'
        '20.190.131.64/27'
        '20.190.131.96/29'
        '20.190.132.0/27'
        '20.190.132.32/29'
        '20.190.132.64/27'
        '20.190.132.96/29'
        '20.190.133.0/27'
        '20.190.133.32/29'
        '20.190.133.64/27'
        '20.190.133.96/29'
        '20.190.134.0/27'
        '20.190.134.32/29'
        '20.190.134.64/27'
        '20.190.134.96/29'
        '20.190.135.0/27'
        '20.190.135.32/29'
        '20.190.135.64/27'
        '20.190.135.96/29'
        '20.190.136.0/27'
        '20.190.136.32/29'
        '20.190.137.0/27'
        '20.190.137.32/29'
        '20.190.137.64/27'
        '20.190.137.96/29'
        '20.190.138.0/27'
        '20.190.138.32/29'
        '20.190.138.64/27'
        '20.190.138.96/29'
        '20.190.138.128/27'
        '20.190.138.160/29'
        '20.190.139.0/27'
        '20.190.139.32/29'
        '20.190.139.64/27'
        '20.190.139.96/29'
        '20.190.139.128/27'
        '20.190.139.160/29'
        '20.190.140.0/27'
        '20.190.140.32/29'
        '20.190.140.64/27'
        '20.190.140.96/29'
        '20.190.140.128/27'
        '20.190.140.160/29'
        '20.190.140.192/27'
        '20.190.140.224/29'
        '20.190.141.0/27'
        '20.190.141.32/29'
        '20.190.141.128/27'
        '20.190.141.160/29'
        '20.190.141.192/27'
        '20.190.141.224/29'
        '20.190.142.0/27'
        '20.190.142.32/29'
        '20.190.142.64/27'
        '20.190.142.96/29'
        '20.190.142.128/27'
        '20.190.142.160/29'
        '20.190.143.0/27'
        '20.190.143.32/29'
        '20.190.143.64/27'
        '20.190.143.96/29'
        '20.190.143.128/27'
        '20.190.143.160/29'
        '20.190.144.0/27'
        '20.190.144.32/29'
        '20.190.144.128/27'
        '20.190.144.160/29'
        '20.190.144.192/27'
        '20.190.144.224/29'
        '20.190.145.0/27'
        '20.190.145.32/29'
        '20.190.145.64/27'
        '20.190.145.96/29'
        '20.190.145.128/27'
        '20.190.145.160/29'
        '20.190.146.0/27'
        '20.190.146.32/29'
        '20.190.146.64/27'
        '20.190.146.96/29'
        '20.190.146.128/27'
        '20.190.146.160/29'
        '20.190.147.0/27'
        '20.190.147.32/29'
        '20.190.147.64/27'
        '20.190.147.96/29'
        '20.190.147.128/27'
        '20.190.147.160/29'
        '20.190.148.0/27'
        '20.190.148.32/29'
        '20.190.148.128/27'
        '20.190.148.160/29'
        '20.190.148.192/27'
        '20.190.148.224/29'
        '20.190.149.0/28'
        '20.190.149.16/29'
        '20.190.149.64/28'
        '20.190.149.80/29'
        '20.190.149.128/28'
        '20.190.149.144/29'
        '20.190.150.0/28'
        '20.190.150.16/29'
        '20.190.150.64/27'
        '20.190.150.96/28'
        '20.190.151.0/28'
        '20.190.151.16/29'
        '20.190.151.64/28'
        '20.190.151.80/29'
        '20.190.151.128/28'
        '20.190.151.144/29'
        '20.190.152.0/28'
        '20.190.152.16/29'
        '20.190.152.64/28'
        '20.190.152.80/29'
        '20.190.152.128/28'
        '20.190.152.144/29'
        '20.190.153.0/28'
        '20.190.153.16/29'
        '20.190.153.64/27'
        '20.190.153.96/28'
        '20.190.154.0/28'
        '20.190.154.16/29'
        '20.190.154.64/28'
        '20.190.154.80/29'
        '20.190.154.128/28'
        '20.190.154.144/29'
        '20.190.155.0/28'
        '20.190.155.16/29'
        '20.190.155.64/28'
        '20.190.155.80/29'
        '20.190.155.128/28'
        '20.190.155.144/29'
        '20.190.156.0/28'
        '20.190.156.16/29'
        '20.190.156.64/27'
        '20.190.156.96/28'
        '20.190.157.0/28'
        '20.190.157.16/29'
        '20.190.157.64/28'
        '20.190.157.80/29'
        '20.190.157.128/28'
        '20.190.157.144/29'
        '20.190.158.0/28'
        '20.190.158.16/29'
        '20.190.158.64/27'
        '20.190.158.96/28'
        '20.190.159.0/28'
        '20.190.159.16/29'
        '20.190.159.64/28'
        '20.190.159.80/29'
        '20.190.159.128/28'
        '20.190.159.144/29'
        '20.190.160.0/28'
        '20.190.160.16/29'
        '20.190.160.64/28'
        '20.190.160.80/29'
        '20.190.160.128/28'
        '20.190.160.144/29'
        '20.190.161.0/28'
        '20.190.161.16/29'
        '20.190.161.64/28'
        '20.190.161.80/29'
        '20.190.161.128/28'
        '20.190.161.144/29'
        '20.190.162.0/28'
        '20.190.162.16/29'
        '20.190.162.64/27'
        '20.190.162.96/28'
        '20.190.163.0/28'
        '20.190.163.16/29'
        '20.190.163.64/28'
        '20.190.163.80/29'
        '20.190.163.128/28'
        '20.190.163.144/29'
        '20.190.164.0/28'
        '20.190.164.16/29'
        '20.190.164.64/27'
        '20.190.164.96/28'
        '20.190.165.0/28'
        '20.190.165.16/29'
        '20.190.165.64/27'
        '20.190.165.96/28'
        '20.190.166.0/28'
        '20.190.166.16/29'
        '20.190.166.64/28'
        '20.190.166.80/29'
        '20.190.166.128/28'
        '20.190.166.144/29'
        '20.190.167.0/28'
        '20.190.167.16/29'
        '20.190.167.64/28'
        '20.190.167.80/29'
        '20.190.167.128/28'
        '20.190.167.144/29'
        '20.190.168.0/28'
        '20.190.168.16/29'
        '20.190.168.64/27'
        '20.190.168.96/28'
        '20.190.169.0/28'
        '20.190.169.16/29'
        '20.190.169.64/28'
        '20.190.169.80/29'
        '20.190.169.128/28'
        '20.190.169.144/29'
        '20.190.170.0/28'
        '20.190.170.16/29'
        '20.190.170.64/27'
        '20.190.170.96/28'
        '20.190.171.0/28'
        '20.190.171.16/29'
        '20.190.171.64/27'
        '20.190.171.96/28'
        '20.190.172.0/28'
        '20.190.172.16/29'
        '20.190.172.64/27'
        '20.190.172.96/28'
        '20.190.173.0/28'
        '20.190.173.16/29'
        '20.190.173.64/28'
        '20.190.173.80/29'
        '20.190.173.128/28'
        '20.190.173.144/29'
        '20.190.174.0/28'
        '20.190.174.16/29'
        '20.190.174.64/27'
        '20.190.174.96/28'
        '20.190.175.0/28'
        '20.190.175.16/29'
        '20.190.175.64/28'
        '20.190.175.80/29'
        '20.190.175.128/28'
        '20.190.175.144/29'
        '20.190.176.0/28'
        '20.190.176.16/29'
        '20.190.176.64/27'
        '20.190.176.96/28'
        '20.190.177.0/28'
        '20.190.177.16/29'
        '20.190.177.64/28'
        '20.190.177.80/29'
        '20.190.177.128/28'
        '20.190.177.144/29'
        '20.190.178.0/28'
        '20.190.178.16/29'
        '20.190.178.64/27'
        '20.190.178.96/28'
        '20.190.179.0/28'
        '20.190.179.16/29'
        '20.190.179.64/27'
        '20.190.179.96/28'
        '20.190.180.0/28'
        '20.190.180.16/29'
        '20.190.180.64/28'
        '20.190.180.80/29'
        '20.190.180.128/28'
        '20.190.180.144/29'
        '20.190.181.0/28'
        '20.190.181.16/29'
        '20.190.181.64/27'
        '20.190.181.96/28'
        '20.190.182.0/28'
        '20.190.182.16/29'
        '20.190.182.64/27'
        '20.190.182.96/28'
        '20.190.183.0/28'
        '20.190.183.16/29'
        '20.190.183.64/27'
        '20.190.183.96/28'
        '20.190.184.0/28'
        '20.190.184.16/29'
        '20.190.184.64/27'
        '20.190.184.96/28'
        '20.190.186.0/28'
        '20.190.186.16/29'
        '20.190.186.64/27'
        '20.190.186.96/28'
        '20.190.187.0/28'
        '20.190.187.16/29'
        '20.190.187.64/27'
        '20.190.187.96/28'
        '20.190.188.0/28'
        '20.190.188.16/29'
        '20.190.188.64/27'
        '20.190.188.96/28'
        '20.190.189.0/27'
        '20.190.189.64/27'
        '20.190.189.128/27'
        '20.190.189.192/27'
        '20.190.190.0/27'
        '20.190.190.64/27'
        '20.190.190.128/27'
        '20.190.190.192/27'
        '20.190.191.0/27'
        '20.190.191.64/27'
        '20.190.191.128/27'
        '20.190.191.192/27'
        '20.231.128.0/27'
        '40.126.0.0/26'
        '40.126.0.64/28'
        '40.126.0.128/27'
        '40.126.0.160/29'
        '40.126.1.0/26'
        '40.126.1.64/28'
        '40.126.1.128/27'
        '40.126.1.160/29'
        '40.126.2.0/27'
        '40.126.2.32/29'
        '40.126.3.0/27'
        '40.126.3.32/29'
        '40.126.3.64/27'
        '40.126.3.96/29'
        '40.126.4.0/27'
        '40.126.4.32/29'
        '40.126.4.64/27'
        '40.126.4.96/29'
        '40.126.5.0/27'
        '40.126.5.32/29'
        '40.126.5.64/27'
        '40.126.5.96/29'
        '40.126.6.0/27'
        '40.126.6.32/29'
        '40.126.6.64/27'
        '40.126.6.96/29'
        '40.126.7.0/27'
        '40.126.7.32/29'
        '40.126.7.64/27'
        '40.126.7.96/29'
        '40.126.8.0/27'
        '40.126.8.32/29'
        '40.126.9.0/27'
        '40.126.9.32/29'
        '40.126.9.64/27'
        '40.126.9.96/29'
        '40.126.10.0/27'
        '40.126.10.32/29'
        '40.126.10.64/27'
        '40.126.10.96/29'
        '40.126.10.128/27'
        '40.126.10.160/29'
        '40.126.11.0/27'
        '40.126.11.32/29'
        '40.126.11.64/27'
        '40.126.11.96/29'
        '40.126.11.128/27'
        '40.126.11.160/29'
        '40.126.12.0/27'
        '40.126.12.32/29'
        '40.126.12.64/27'
        '40.126.12.96/29'
        '40.126.12.128/27'
        '40.126.12.160/29'
        '40.126.12.192/27'
        '40.126.12.224/29'
        '40.126.13.0/27'
        '40.126.13.32/29'
        '40.126.13.128/27'
        '40.126.13.160/29'
        '40.126.13.192/27'
        '40.126.13.224/29'
        '40.126.14.0/27'
        '40.126.14.32/29'
        '40.126.14.64/27'
        '40.126.14.96/29'
        '40.126.14.128/27'
        '40.126.14.160/29'
        '40.126.15.0/27'
        '40.126.15.32/29'
        '40.126.15.64/27'
        '40.126.15.96/29'
        '40.126.15.128/27'
        '40.126.15.160/29'
        '40.126.16.0/27'
        '40.126.16.32/29'
        '40.126.16.128/27'
        '40.126.16.160/29'
        '40.126.16.192/27'
        '40.126.16.224/29'
        '40.126.17.0/27'
        '40.126.17.32/29'
        '40.126.17.64/27'
        '40.126.17.96/29'
        '40.126.17.128/27'
        '40.126.17.160/29'
        '40.126.18.0/27'
        '40.126.18.32/29'
        '40.126.18.64/27'
        '40.126.18.96/29'
        '40.126.18.128/27'
        '40.126.18.160/29'
        '40.126.19.0/27'
        '40.126.19.32/29'
        '40.126.19.64/27'
        '40.126.19.96/29'
        '40.126.19.128/27'
        '40.126.19.160/29'
        '40.126.20.0/27'
        '40.126.20.32/29'
        '40.126.20.128/27'
        '40.126.20.160/29'
        '40.126.20.192/27'
        '40.126.20.224/29'
        '40.126.21.0/28'
        '40.126.21.16/29'
        '40.126.21.64/28'
        '40.126.21.80/29'
        '40.126.21.128/28'
        '40.126.21.144/29'
        '40.126.22.0/28'
        '40.126.22.16/29'
        '40.126.22.64/27'
        '40.126.22.96/28'
        '40.126.23.0/28'
        '40.126.23.16/29'
        '40.126.23.64/28'
        '40.126.23.80/29'
        '40.126.23.128/28'
        '40.126.23.144/29'
        '40.126.24.0/28'
        '40.126.24.16/29'
        '40.126.24.64/28'
        '40.126.24.80/29'
        '40.126.24.128/28'
        '40.126.24.144/29'
        '40.126.25.0/28'
        '40.126.25.16/29'
        '40.126.25.64/27'
        '40.126.25.96/28'
        '40.126.26.0/28'
        '40.126.26.16/29'
        '40.126.26.64/28'
        '40.126.26.80/29'
        '40.126.26.128/28'
        '40.126.26.144/29'
        '40.126.27.0/28'
        '40.126.27.16/29'
        '40.126.27.64/28'
        '40.126.27.80/29'
        '40.126.27.128/28'
        '40.126.27.144/29'
        '40.126.28.0/28'
        '40.126.28.16/29'
        '40.126.28.64/27'
        '40.126.28.96/28'
        '40.126.29.0/28'
        '40.126.29.16/29'
        '40.126.29.64/28'
        '40.126.29.80/29'
        '40.126.29.128/28'
        '40.126.29.144/29'
        '40.126.30.0/28'
        '40.126.30.16/29'
        '40.126.30.64/27'
        '40.126.30.96/28'
        '40.126.31.0/28'
        '40.126.31.16/29'
        '40.126.31.64/28'
        '40.126.31.80/29'
        '40.126.31.128/28'
        '40.126.31.144/29'
        '40.126.32.0/28'
        '40.126.32.16/29'
        '40.126.32.64/28'
        '40.126.32.80/29'
        '40.126.32.128/28'
        '40.126.32.144/29'
        '40.126.33.0/28'
        '40.126.33.16/29'
        '40.126.33.64/28'
        '40.126.33.80/29'
        '40.126.33.128/28'
        '40.126.33.144/29'
        '40.126.34.0/28'
        '40.126.34.16/29'
        '40.126.34.64/27'
        '40.126.34.96/28'
        '40.126.35.0/28'
        '40.126.35.16/29'
        '40.126.35.64/28'
        '40.126.35.80/29'
        '40.126.35.128/28'
        '40.126.35.144/29'
        '40.126.36.0/28'
        '40.126.36.16/29'
        '40.126.36.64/27'
        '40.126.36.96/28'
        '40.126.37.0/28'
        '40.126.37.16/29'
        '40.126.37.64/27'
        '40.126.37.96/28'
        '40.126.38.0/28'
        '40.126.38.16/29'
        '40.126.38.64/28'
        '40.126.38.80/29'
        '40.126.38.128/28'
        '40.126.38.144/29'
        '40.126.39.0/28'
        '40.126.39.16/29'
        '40.126.39.64/28'
        '40.126.39.80/29'
        '40.126.39.128/28'
        '40.126.39.144/29'
        '40.126.40.0/28'
        '40.126.40.16/29'
        '40.126.40.64/27'
        '40.126.40.96/28'
        '40.126.41.0/28'
        '40.126.41.16/29'
        '40.126.41.64/28'
        '40.126.41.80/29'
        '40.126.41.128/28'
        '40.126.41.144/29'
        '40.126.42.0/28'
        '40.126.42.16/29'
        '40.126.42.64/27'
        '40.126.42.96/28'
        '40.126.43.0/28'
        '40.126.43.16/29'
        '40.126.43.64/27'
        '40.126.43.96/28'
        '40.126.44.0/28'
        '40.126.44.16/29'
        '40.126.44.64/27'
        '40.126.44.96/28'
        '40.126.45.0/28'
        '40.126.45.16/29'
        '40.126.45.64/28'
        '40.126.45.80/29'
        '40.126.45.128/28'
        '40.126.45.144/29'
        '40.126.46.0/28'
        '40.126.46.16/29'
        '40.126.46.64/27'
        '40.126.46.96/28'
        '40.126.47.0/28'
        '40.126.47.16/29'
        '40.126.47.64/28'
        '40.126.47.80/29'
        '40.126.47.128/28'
        '40.126.47.144/29'
        '40.126.48.0/28'
        '40.126.48.16/29'
        '40.126.48.64/27'
        '40.126.48.96/28'
        '40.126.49.0/28'
        '40.126.49.16/29'
        '40.126.49.64/28'
        '40.126.49.80/29'
        '40.126.49.128/28'
        '40.126.49.144/29'
        '40.126.50.0/28'
        '40.126.50.16/29'
        '40.126.50.64/27'
        '40.126.50.96/28'
        '40.126.51.0/28'
        '40.126.51.16/29'
        '40.126.51.64/27'
        '40.126.51.96/28'
        '40.126.52.0/28'
        '40.126.52.16/29'
        '40.126.52.64/28'
        '40.126.52.80/29'
        '40.126.52.128/28'
        '40.126.52.144/29'
        '40.126.53.0/28'
        '40.126.53.16/29'
        '40.126.53.64/27'
        '40.126.53.96/28'
        '40.126.54.0/28'
        '40.126.54.16/29'
        '40.126.54.64/27'
        '40.126.54.96/28'
        '40.126.55.0/28'
        '40.126.55.16/29'
        '40.126.55.64/27'
        '40.126.55.96/28'
        '40.126.56.0/28'
        '40.126.56.16/29'
        '40.126.56.64/27'
        '40.126.56.96/28'
        '40.126.58.0/28'
        '40.126.58.16/29'
        '40.126.58.64/27'
        '40.126.58.96/28'
        '40.126.59.0/28'
        '40.126.59.16/29'
        '40.126.59.64/27'
        '40.126.59.96/28'
        '40.126.60.0/28'
        '40.126.60.16/29'
        '40.126.60.64/27'
        '40.126.60.96/28'
        '40.126.61.0/27'
        '40.126.61.64/27'
        '40.126.61.128/27'
        '40.126.61.192/27'
        '40.126.62.0/27'
        '40.126.62.64/27'
        '40.126.62.128/27'
        '40.126.63.0/27'
        '40.126.63.64/27'
        '40.126.63.128/27'
        '40.126.63.192/27'
        // '2603:1006:2000::/121'
        // '2603:1006:2000:8::/121'
        // '2603:1006:2000:10::/121'
        // '2603:1006:2000:18::/121'
        // '2603:1006:2000:20::/121'
        // '2603:1007:200::/121'
        // '2603:1007:200:8::/121'
        // '2603:1007:200:10::/121'
        // '2603:1007:200:18::/121'
        // '2603:1007:200:20::/121'
        // '2603:1016:1400::/121'
        // '2603:1016:1400:20::/121'
        // '2603:1016:1400:40::/121'
        // '2603:1016:1400:60::/121'
        // '2603:1016:1400:68::/121'
        // '2603:1016:1400:70::/121'
        // '2603:1016:1400:78::/121'
        // '2603:1017::/121'
        // '2603:1017:0:20::/121'
        // '2603:1017:0:40::/121'
        // '2603:1017:0:60::/121'
        // '2603:1017:0:68::/121'
        // '2603:1017:0:70::/121'
        // '2603:1017:0:78::/121'
        // '2603:1026:3000::/121'
        // '2603:1026:3000:20::/121'
        // '2603:1026:3000:40::/121'
        // '2603:1026:3000:60::/121'
        // '2603:1026:3000:80::/121'
        // '2603:1026:3000:a0::/121'
        // '2603:1026:3000:c0::/121'
        // '2603:1026:3000:c8::/121'
        // '2603:1026:3000:d0::/121'
        // '2603:1026:3000:d8::/121'
        // '2603:1026:3000:e0::/121'
        // '2603:1026:3000:e8::/121'
        // '2603:1026:3000:f0::/121'
        // '2603:1026:3000:f8::/121'
        // '2603:1026:3000:100::/121'
        // '2603:1026:3000:108::/121'
        // '2603:1026:3000:110::/121'
        // '2603:1026:3000:118::/121'
        // '2603:1026:3000:120::/121'
        // '2603:1026:3000:140::/121'
        // '2603:1026:3000:148::/121'
        // '2603:1026:3000:150::/121'
        // '2603:1026:3000:158::/121'
        // '2603:1026:3000:160::/121'
        // '2603:1026:3000:1a0::/121'
        // '2603:1026:3000:1c0::/121'
        // '2603:1026:3000:1e0::/121'
        // '2603:1026:3000:200::/121'
        // '2603:1026:3000:220::/121'
        // '2603:1027:1::/121'
        // '2603:1027:1:20::/121'
        // '2603:1027:1:40::/121'
        // '2603:1027:1:60::/121'
        // '2603:1027:1:80::/121'
        // '2603:1027:1:a0::/121'
        // '2603:1027:1:c0::/121'
        // '2603:1027:1:c8::/121'
        // '2603:1027:1:d0::/121'
        // '2603:1027:1:d8::/121'
        // '2603:1027:1:e0::/121'
        // '2603:1027:1:e8::/121'
        // '2603:1027:1:f0::/121'
        // '2603:1027:1:f8::/121'
        // '2603:1027:1:100::/121'
        // '2603:1027:1:108::/121'
        // '2603:1027:1:110::/121'
        // '2603:1027:1:118::/121'
        // '2603:1027:1:120::/121'
        // '2603:1027:1:140::/121'
        // '2603:1027:1:148::/121'
        // '2603:1027:1:150::/121'
        // '2603:1027:1:158::/121'
        // '2603:1027:1:160::/121'
        // '2603:1027:1:1a0::/121'
        // '2603:1027:1:1c0::/121'
        // '2603:1027:1:1e0::/121'
        // '2603:1027:1:200::/121'
        // '2603:1027:1:220::/121'
        // '2603:1030:107:2::80/121'
        // '2603:1036:3000::/121'
        // '2603:1036:3000:8::/121'
        // '2603:1036:3000:10::/121'
        // '2603:1036:3000:18::/121'
        // '2603:1036:3000:20::/121'
        // '2603:1036:3000:28::/121'
        // '2603:1036:3000:30::/121'
        // '2603:1036:3000:38::/121'
        // '2603:1036:3000:40::/121'
        // '2603:1036:3000:48::/121'
        // '2603:1036:3000:50::/121'
        // '2603:1036:3000:58::/121'
        // '2603:1036:3000:60::/121'
        // '2603:1036:3000:80::/121'
        // '2603:1036:3000:a0::/121'
        // '2603:1036:3000:c0::/121'
        // '2603:1036:3000:c8::/121'
        // '2603:1036:3000:d0::/121'
        // '2603:1036:3000:d8::/121'
        // '2603:1036:3000:e0::/121'
        // '2603:1036:3000:e8::/121'
        // '2603:1036:3000:f0::/121'
        // '2603:1036:3000:f8::/121'
        // '2603:1036:3000:100::/121'
        // '2603:1036:3000:108::/121'
        // '2603:1036:3000:110::/121'
        // '2603:1036:3000:118::/121'
        // '2603:1036:3000:120::/121'
        // '2603:1036:3000:128::/121'
        // '2603:1036:3000:130::/121'
        // '2603:1036:3000:138::/121'
        // '2603:1036:3000:140::/121'
        // '2603:1036:3000:148::/121'
        // '2603:1036:3000:150::/121'
        // '2603:1036:3000:158::/121'
        // '2603:1036:3000:160::/121'
        // '2603:1036:3000:180::/121'
        // '2603:1036:3000:1a0::/121'
        // '2603:1036:3000:1c0::/121'
        // '2603:1037:1::/121'
        // '2603:1037:1:8::/121'
        // '2603:1037:1:10::/121'
        // '2603:1037:1:18::/121'
        // '2603:1037:1:20::/121'
        // '2603:1037:1:28::/121'
        // '2603:1037:1:30::/121'
        // '2603:1037:1:38::/121'
        // '2603:1037:1:40::/121'
        // '2603:1037:1:48::/121'
        // '2603:1037:1:50::/121'
        // '2603:1037:1:58::/121'
        // '2603:1037:1:60::/121'
        // '2603:1037:1:80::/121'
        // '2603:1037:1:a0::/121'
        // '2603:1037:1:c0::/121'
        // '2603:1037:1:c8::/121'
        // '2603:1037:1:d0::/121'
        // '2603:1037:1:d8::/121'
        // '2603:1037:1:e0::/121'
        // '2603:1037:1:e8::/121'
        // '2603:1037:1:f0::/121'
        // '2603:1037:1:f8::/121'
        // '2603:1037:1:100::/121'
        // '2603:1037:1:108::/121'
        // '2603:1037:1:110::/121'
        // '2603:1037:1:118::/121'
        // '2603:1037:1:120::/121'
        // '2603:1037:1:128::/121'
        // '2603:1037:1:130::/121'
        // '2603:1037:1:138::/121'
        // '2603:1037:1:140::/121'
        // '2603:1037:1:148::/121'
        // '2603:1037:1:150::/121'
        // '2603:1037:1:158::/121'
        // '2603:1037:1:160::/121'
        // '2603:1037:1:180::/121'
        // '2603:1037:1:1a0::/121'
        // '2603:1037:1:1c0::/121'
        // '2603:1046:2000:20::/121'
        // '2603:1046:2000:40::/121'
        // '2603:1046:2000:60::/121'
        // '2603:1046:2000:80::/121'
        // '2603:1046:2000:88::/121'
        // '2603:1046:2000:90::/121'
        // '2603:1046:2000:98::/121'
        // '2603:1046:2000:a0::/121'
        // '2603:1046:2000:e0::/121'
        // '2603:1046:2000:100::/121'
        // '2603:1046:2000:120::/121'
        // '2603:1046:2000:140::/121'
        // '2603:1046:2000:148::/121'
        // '2603:1046:2000:150::/121'
        // '2603:1046:2000:158::/121'
        // '2603:1046:2000:160::/121'
        // '2603:1046:2000:168::/121'
        // '2603:1046:2000:170::/121'
        // '2603:1046:2000:178::/121'
        // '2603:1046:2000:180::/121'
        // '2603:1046:2000:188::/121'
        // '2603:1046:2000:190::/121'
        // '2603:1046:2000:198::/121'
        // '2603:1046:2000:1a0::/121'
        // '2603:1046:2000:1c0::/121'
        // '2603:1046:2000:1e0::/121'
        // '2603:1047:1:20::/121'
        // '2603:1047:1:40::/121'
        // '2603:1047:1:60::/121'
        // '2603:1047:1:80::/121'
        // '2603:1047:1:88::/121'
        // '2603:1047:1:90::/121'
        // '2603:1047:1:98::/121'
        // '2603:1047:1:a0::/121'
        // '2603:1047:1:e0::/121'
        // '2603:1047:1:100::/121'
        // '2603:1047:1:120::/121'
        // '2603:1047:1:140::/121'
        // '2603:1047:1:148::/121'
        // '2603:1047:1:150::/121'
        // '2603:1047:1:158::/121'
        // '2603:1047:1:160::/121'
        // '2603:1047:1:168::/121'
        // '2603:1047:1:170::/121'
        // '2603:1047:1:178::/121'
        // '2603:1047:1:180::/121'
        // '2603:1047:1:188::/121'
        // '2603:1047:1:190::/121'
        // '2603:1047:1:198::/121'
        // '2603:1047:1:1a0::/121'
        // '2603:1047:1:1c0::/121'
        // '2603:1047:1:1e0::/121'
        // '2603:1056:2000:20::/121'
        // '2603:1056:2000:28::/121'
        // '2603:1056:2000:30::/121'
        // '2603:1056:2000:38::/121'
        // '2603:1056:2000:60::/121'
        // '2603:1057:2:20::/121'
        // '2603:1057:2:28::/121'
        // '2603:1057:2:30::/121'
        // '2603:1057:2:38::/121'
        // '2603:1057:2:60::/121'
      ]
      destinationPortRanges: [
        '80'
        '443'
      ]
    }
  }
  {
    name: 'Allow_AzureAD_IPv6'
    properties: {
      direction: 'Outbound'
      priority: 212
      protocol: 'TCP'
      access: 'Allow'
      sourceAddressPrefix: 'VirtualNetwork'
      sourcePortRange: '*'
      destinationAddressPrefixes: [
        // From JSON https://www.microsoft.com/en-us/download/details.aspx?id=56519
        '2603:1006:2000::/121'
        '2603:1006:2000:8::/121'
        '2603:1006:2000:10::/121'
        '2603:1006:2000:18::/121'
        '2603:1006:2000:20::/121'
        '2603:1007:200::/121'
        '2603:1007:200:8::/121'
        '2603:1007:200:10::/121'
        '2603:1007:200:18::/121'
        '2603:1007:200:20::/121'
        '2603:1016:1400::/121'
        '2603:1016:1400:20::/121'
        '2603:1016:1400:40::/121'
        '2603:1016:1400:60::/121'
        '2603:1016:1400:68::/121'
        '2603:1016:1400:70::/121'
        '2603:1016:1400:78::/121'
        '2603:1017::/121'
        '2603:1017:0:20::/121'
        '2603:1017:0:40::/121'
        '2603:1017:0:60::/121'
        '2603:1017:0:68::/121'
        '2603:1017:0:70::/121'
        '2603:1017:0:78::/121'
        '2603:1026:3000::/121'
        '2603:1026:3000:20::/121'
        '2603:1026:3000:40::/121'
        '2603:1026:3000:60::/121'
        '2603:1026:3000:80::/121'
        '2603:1026:3000:a0::/121'
        '2603:1026:3000:c0::/121'
        '2603:1026:3000:c8::/121'
        '2603:1026:3000:d0::/121'
        '2603:1026:3000:d8::/121'
        '2603:1026:3000:e0::/121'
        '2603:1026:3000:e8::/121'
        '2603:1026:3000:f0::/121'
        '2603:1026:3000:f8::/121'
        '2603:1026:3000:100::/121'
        '2603:1026:3000:108::/121'
        '2603:1026:3000:110::/121'
        '2603:1026:3000:118::/121'
        '2603:1026:3000:120::/121'
        '2603:1026:3000:140::/121'
        '2603:1026:3000:148::/121'
        '2603:1026:3000:150::/121'
        '2603:1026:3000:158::/121'
        '2603:1026:3000:160::/121'
        '2603:1026:3000:1a0::/121'
        '2603:1026:3000:1c0::/121'
        '2603:1026:3000:1e0::/121'
        '2603:1026:3000:200::/121'
        '2603:1026:3000:220::/121'
        '2603:1027:1::/121'
        '2603:1027:1:20::/121'
        '2603:1027:1:40::/121'
        '2603:1027:1:60::/121'
        '2603:1027:1:80::/121'
        '2603:1027:1:a0::/121'
        '2603:1027:1:c0::/121'
        '2603:1027:1:c8::/121'
        '2603:1027:1:d0::/121'
        '2603:1027:1:d8::/121'
        '2603:1027:1:e0::/121'
        '2603:1027:1:e8::/121'
        '2603:1027:1:f0::/121'
        '2603:1027:1:f8::/121'
        '2603:1027:1:100::/121'
        '2603:1027:1:108::/121'
        '2603:1027:1:110::/121'
        '2603:1027:1:118::/121'
        '2603:1027:1:120::/121'
        '2603:1027:1:140::/121'
        '2603:1027:1:148::/121'
        '2603:1027:1:150::/121'
        '2603:1027:1:158::/121'
        '2603:1027:1:160::/121'
        '2603:1027:1:1a0::/121'
        '2603:1027:1:1c0::/121'
        '2603:1027:1:1e0::/121'
        '2603:1027:1:200::/121'
        '2603:1027:1:220::/121'
        '2603:1030:107:2::80/121'
        '2603:1036:3000::/121'
        '2603:1036:3000:8::/121'
        '2603:1036:3000:10::/121'
        '2603:1036:3000:18::/121'
        '2603:1036:3000:20::/121'
        '2603:1036:3000:28::/121'
        '2603:1036:3000:30::/121'
        '2603:1036:3000:38::/121'
        '2603:1036:3000:40::/121'
        '2603:1036:3000:48::/121'
        '2603:1036:3000:50::/121'
        '2603:1036:3000:58::/121'
        '2603:1036:3000:60::/121'
        '2603:1036:3000:80::/121'
        '2603:1036:3000:a0::/121'
        '2603:1036:3000:c0::/121'
        '2603:1036:3000:c8::/121'
        '2603:1036:3000:d0::/121'
        '2603:1036:3000:d8::/121'
        '2603:1036:3000:e0::/121'
        '2603:1036:3000:e8::/121'
        '2603:1036:3000:f0::/121'
        '2603:1036:3000:f8::/121'
        '2603:1036:3000:100::/121'
        '2603:1036:3000:108::/121'
        '2603:1036:3000:110::/121'
        '2603:1036:3000:118::/121'
        '2603:1036:3000:120::/121'
        '2603:1036:3000:128::/121'
        '2603:1036:3000:130::/121'
        '2603:1036:3000:138::/121'
        '2603:1036:3000:140::/121'
        '2603:1036:3000:148::/121'
        '2603:1036:3000:150::/121'
        '2603:1036:3000:158::/121'
        '2603:1036:3000:160::/121'
        '2603:1036:3000:180::/121'
        '2603:1036:3000:1a0::/121'
        '2603:1036:3000:1c0::/121'
        '2603:1037:1::/121'
        '2603:1037:1:8::/121'
        '2603:1037:1:10::/121'
        '2603:1037:1:18::/121'
        '2603:1037:1:20::/121'
        '2603:1037:1:28::/121'
        '2603:1037:1:30::/121'
        '2603:1037:1:38::/121'
        '2603:1037:1:40::/121'
        '2603:1037:1:48::/121'
        '2603:1037:1:50::/121'
        '2603:1037:1:58::/121'
        '2603:1037:1:60::/121'
        '2603:1037:1:80::/121'
        '2603:1037:1:a0::/121'
        '2603:1037:1:c0::/121'
        '2603:1037:1:c8::/121'
        '2603:1037:1:d0::/121'
        '2603:1037:1:d8::/121'
        '2603:1037:1:e0::/121'
        '2603:1037:1:e8::/121'
        '2603:1037:1:f0::/121'
        '2603:1037:1:f8::/121'
        '2603:1037:1:100::/121'
        '2603:1037:1:108::/121'
        '2603:1037:1:110::/121'
        '2603:1037:1:118::/121'
        '2603:1037:1:120::/121'
        '2603:1037:1:128::/121'
        '2603:1037:1:130::/121'
        '2603:1037:1:138::/121'
        '2603:1037:1:140::/121'
        '2603:1037:1:148::/121'
        '2603:1037:1:150::/121'
        '2603:1037:1:158::/121'
        '2603:1037:1:160::/121'
        '2603:1037:1:180::/121'
        '2603:1037:1:1a0::/121'
        '2603:1037:1:1c0::/121'
        '2603:1046:2000:20::/121'
        '2603:1046:2000:40::/121'
        '2603:1046:2000:60::/121'
        '2603:1046:2000:80::/121'
        '2603:1046:2000:88::/121'
        '2603:1046:2000:90::/121'
        '2603:1046:2000:98::/121'
        '2603:1046:2000:a0::/121'
        '2603:1046:2000:e0::/121'
        '2603:1046:2000:100::/121'
        '2603:1046:2000:120::/121'
        '2603:1046:2000:140::/121'
        '2603:1046:2000:148::/121'
        '2603:1046:2000:150::/121'
        '2603:1046:2000:158::/121'
        '2603:1046:2000:160::/121'
        '2603:1046:2000:168::/121'
        '2603:1046:2000:170::/121'
        '2603:1046:2000:178::/121'
        '2603:1046:2000:180::/121'
        '2603:1046:2000:188::/121'
        '2603:1046:2000:190::/121'
        '2603:1046:2000:198::/121'
        '2603:1046:2000:1a0::/121'
        '2603:1046:2000:1c0::/121'
        '2603:1046:2000:1e0::/121'
        '2603:1047:1:20::/121'
        '2603:1047:1:40::/121'
        '2603:1047:1:60::/121'
        '2603:1047:1:80::/121'
        '2603:1047:1:88::/121'
        '2603:1047:1:90::/121'
        '2603:1047:1:98::/121'
        '2603:1047:1:a0::/121'
        '2603:1047:1:e0::/121'
        '2603:1047:1:100::/121'
        '2603:1047:1:120::/121'
        '2603:1047:1:140::/121'
        '2603:1047:1:148::/121'
        '2603:1047:1:150::/121'
        '2603:1047:1:158::/121'
        '2603:1047:1:160::/121'
        '2603:1047:1:168::/121'
        '2603:1047:1:170::/121'
        '2603:1047:1:178::/121'
        '2603:1047:1:180::/121'
        '2603:1047:1:188::/121'
        '2603:1047:1:190::/121'
        '2603:1047:1:198::/121'
        '2603:1047:1:1a0::/121'
        '2603:1047:1:1c0::/121'
        '2603:1047:1:1e0::/121'
        '2603:1056:2000:20::/121'
        '2603:1056:2000:28::/121'
        '2603:1056:2000:30::/121'
        '2603:1056:2000:38::/121'
        '2603:1056:2000:60::/121'
        '2603:1057:2:20::/121'
        '2603:1057:2:28::/121'
        '2603:1057:2:30::/121'
        '2603:1057:2:38::/121'
        '2603:1057:2:60::/121'
      ]
      destinationPortRanges: [
        '80'
        '443'
      ]
    }
  }
  {
    name: 'Allow_GuestAndHybridManagement'
    properties: {
      direction: 'Outbound'
      priority: 260
      protocol: '*'
      access: 'Allow'
      sourceAddressPrefix: 'VirtualNetwork'
      sourcePortRange: '*'
      destinationAddressPrefix: 'GuestAndHybridManagement'
      destinationPortRange: '*'
    }
  }
  {
    name: 'Deny_Internet'
    properties: {
      direction: 'Outbound'
      priority: 4096
      protocol: '*'
      access: 'Deny'
      sourceAddressPrefix: 'VirtualNetwork'
      sourcePortRange: '*'
      destinationAddressPrefix: 'Internet'
      destinationPortRange: '*'
    }
  }
]

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: replace(namingStructure, '{rtype}', 'nsg')
  location: location
  properties: {
    securityRules: securityRules
  }
}

output nsgId string = nsg.id
