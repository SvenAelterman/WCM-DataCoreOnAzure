/*
 * Creates a short name for the given structure and values that is no longer than the maximum specified length
 * How this is shorter than the standard naming convention
 * - Saves usually 1 character on the sequence (01 vs. 1)
 * - Saves a few characters in the location name (eastus vs. eus)
 * - Takes only the first character of the environment (prod = p, demo or dev = d, test = t)
 * - Ensures the max length does not exceed the specified value
 */

param namingConvention string
param location string
@allowed([
  'kv'
  'st'
])
param resourceType string
param environment string
param workloadName string
param sequence int
param removeHyphens bool = false

var Defs = {
  kv: {
    lowerCase: false
    maxLength: 24
  }
  st: {
    lowerCase: true
    maxLength: 23
  }
}

var shortLocations = {
  eastus: 'eus'
  eastus2: 'eus2'
}

var maxLength = Defs[resourceType].maxLength
var lowerCase = Defs[resourceType].lowerCase

// Translate the regular location value to a shorter value
var shortLocationValue = shortLocations[location]
var shortNameAnyLength = replace(replace(replace(replace(replace(namingConvention, '{env}', toLower(take(environment, 1))), '{loc}', shortLocationValue), '{seq}', string(sequence)), '{wloadname}', workloadName), '{rtype}', resourceType)
var shortNameAnyLengthHyphensProcessed = removeHyphens ? replace(shortNameAnyLength, '-', '') : shortNameAnyLength
var shortNameAnyLengthHyphensProcessedCased = lowerCase ? toLower(shortNameAnyLengthHyphensProcessed) : shortNameAnyLengthHyphensProcessed

output shortName string = take(shortNameAnyLengthHyphensProcessedCased, maxLength)
