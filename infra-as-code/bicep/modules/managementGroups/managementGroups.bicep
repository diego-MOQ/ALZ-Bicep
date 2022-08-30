targetScope = 'tenant'

@description('Prefix for the management group hierarchy.  This management group will be created as part of the deployment.')
@minLength(2)
@maxLength(10)
param parTopLevelManagementGroupPrefix string = 'IBAC'

@description('Display name for top level management group.  This name will be applied to the management group prefix defined in parTopLevelManagementGroupPrefix parameter.')
@minLength(2)
param parTopLevelManagementGroupDisplayName string = 'IBAC-MG-BASE-ALL'

@description('Optional parent for Management Group hierarchy, used as intermediate root Management Group parent, if specified. If empty, default, will deploy beneath Tenant Root Management Group.')
param parTopLevelManagementGroupParentId string = ''

@description('Deploys Corp & Online Management Groups beneath Landing Zones Management Group if set to true.')
param parLandingZoneMgAlzDefaultsEnable bool = true

@description('Deploys Confidential Corp & Confidential Online Management Groups beneath Landing Zones Management Group if set to true.')
param parLandingZoneMgConfidentialEnable bool = false

@description('Dictionary Object to allow additional or different child Management Groups of Landing Zones Management Group to be deployed.')
param parLandingZoneMgChildren object = {}

@description('Set Parameter to true to Opt-out of deployment telemetry')
param parTelemetryOptOut bool = false

// Platform and Child Management Groups
var varPlatformMg = {
  name: '${parTopLevelManagementGroupPrefix}-MG-CPL-ALL'
  displayName: 'IBAC-MG-CPL-ALL'
}

var varPlatformManagementMg = {
  name: '${parTopLevelManagementGroupPrefix}-MG-HUB-PRD1'
  displayName: 'IBAC-MG-HUB-PRD1'
}

// Landing Zones & Child Management Groups
var varLandingZoneMg = {
  name: '${parTopLevelManagementGroupPrefix}-MG-LDZ-ALL'
  displayName: 'IBAC-MG-LDZ-ALL'
}

// Used if parLandingZoneMgAlzDefaultsEnable == true
var varLandingZoneMgChildrenAlzDefault = {
  PROD: {
    displayName: 'PROD'
  }
  DR: {
    displayName: 'DR'
  }
}

// Used if parLandingZoneMgConfidentialEnable == true
var varLandingZoneMgChildrenConfidential = {
  'confidential-prod': {
    displayName: 'Confidential Prod'
  }
  'confidential-dr': {
    displayName: 'Confidential DR'
  }
}

// Build final onject based on input parameters for child MGs of LZs
var varLandingZoneMgChildrenUnioned = (parLandingZoneMgAlzDefaultsEnable && parLandingZoneMgConfidentialEnable && (!empty(parLandingZoneMgChildren))) ? union(varLandingZoneMgChildrenAlzDefault, varLandingZoneMgChildrenConfidential, parLandingZoneMgChildren) : (parLandingZoneMgAlzDefaultsEnable && parLandingZoneMgConfidentialEnable && (empty(parLandingZoneMgChildren))) ? union(varLandingZoneMgChildrenAlzDefault, varLandingZoneMgChildrenConfidential) : (parLandingZoneMgAlzDefaultsEnable && !parLandingZoneMgConfidentialEnable && (!empty(parLandingZoneMgChildren))) ? union(varLandingZoneMgChildrenAlzDefault, parLandingZoneMgChildren) : (parLandingZoneMgAlzDefaultsEnable && !parLandingZoneMgConfidentialEnable && (empty(parLandingZoneMgChildren))) ? varLandingZoneMgChildrenAlzDefault : (!parLandingZoneMgAlzDefaultsEnable && parLandingZoneMgConfidentialEnable && (!empty(parLandingZoneMgChildren))) ? union(varLandingZoneMgChildrenConfidential, parLandingZoneMgChildren) : (!parLandingZoneMgAlzDefaultsEnable && parLandingZoneMgConfidentialEnable && (empty(parLandingZoneMgChildren))) ? varLandingZoneMgChildrenConfidential : (!parLandingZoneMgAlzDefaultsEnable && !parLandingZoneMgConfidentialEnable && (!empty(parLandingZoneMgChildren))) ? parLandingZoneMgChildren : (!parLandingZoneMgAlzDefaultsEnable && !parLandingZoneMgConfidentialEnable && (empty(parLandingZoneMgChildren))) ? {} : {}


// Customer Usage Attribution Id
var varCuaid = '9b7965a0-d77c-41d6-85ef-ec3dfea4845b'

// Level 1
resource resTopLevelMg 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: parTopLevelManagementGroupPrefix
  properties: {
    displayName: parTopLevelManagementGroupDisplayName
    details: {
      parent: {
        id: (empty(parTopLevelManagementGroupParentId) ? '/providers/Microsoft.Management/managementGroups/${tenant().tenantId}' : parTopLevelManagementGroupParentId)
      }
    }
  }
}

// Level 2
resource resPlatformMg 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: varPlatformMg.name
  properties: {
    displayName: varPlatformMg.displayName
    details: {
      parent: {
        id: resTopLevelMg.id
      }
    }
  }
}

resource resLandingZonesMg 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: varLandingZoneMg.name
  properties: {
    displayName: varLandingZoneMg.displayName
    details: {
      parent: {
        id: resTopLevelMg.id
      }
    }
  }
}

// Level 3 - Child Management Groups under Platform MG
resource resPlatformManagementMg 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: varPlatformManagementMg.name
  properties: {
    displayName: varPlatformManagementMg.displayName
    details: {
      parent: {
        id: resPlatformMg.id
      }
    }
  }
}

// Level 3 - Child Management Groups under Landing Zones MG

resource resLandingZonesChildMgs 'Microsoft.Management/managementGroups@2021-04-01' = [for mg in items(varLandingZoneMgChildrenUnioned): if (!empty(varLandingZoneMgChildrenUnioned)) {
  name: '${parTopLevelManagementGroupPrefix}-MG-LDZ-${mg.key}'
  properties: {
    displayName: mg.value.displayName
    details: {
      parent: {
        id: resLandingZonesMg.id
      }
    }
  }
}]

// Optional Deployment for Customer Usage Attribution
module modCustomerUsageAttribution '../../CRML/customerUsageAttribution/cuaIdTenant.bicep' = if (!parTelemetryOptOut) {
  #disable-next-line no-loc-expr-outside-params //Only to ensure telemetry data is stored in same location as deployment. See https://github.com/Azure/ALZ-Bicep/wiki/FAQ#why-are-some-linter-rules-disabled-via-the-disable-next-line-bicep-function for more information //Only to ensure telemetry data is stored in same location as deployment. See https://github.com/Azure/ALZ-Bicep/wiki/FAQ#why-are-some-linter-rules-disabled-via-the-disable-next-line-bicep-function for more information
  name: 'pid-${varCuaid}-${uniqueString(deployment().location)}'
  params: {}
}

// Output Management Group IDs
output outTopLevelManagementGroupId string = resTopLevelMg.id

output outPlatformManagementGroupId string = resPlatformMg.id
output outPlatformManagementManagementGroupId string = resPlatformManagementMg.id
output outLandingZonesManagementGroupId string = resLandingZonesMg.id
output outLandingZoneChildrenMangementGroupIds array = [for mg in items(varLandingZoneMgChildrenUnioned): '/providers/Microsoft.Management/managementGroups/${parTopLevelManagementGroupPrefix}-MG-LDZ-${mg.key}' ]

// Output Management Group Names
output outTopLevelManagementGroupName string = resTopLevelMg.name

output outPlatformManagementGroupName string = resPlatformMg.name
output outPlatformManagementManagementGroupName string = resPlatformManagementMg.name
output outLandingZonesManagementGroupName string = resLandingZonesMg.name
output outLandingZoneChildrenMangementGroupNames array = [for mg in items(varLandingZoneMgChildrenUnioned): mg.value.displayName ]

