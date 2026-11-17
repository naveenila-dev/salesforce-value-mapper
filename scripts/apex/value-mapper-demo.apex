// Execute after deploying the four fictional demo metadata records.
MappingRequest commonRequest = new MappingRequest(null, null, 'EmploymentType', 'Part time');
MappingResult commonResult = MappingResolver.resolve(commonRequest);
System.assertEquals('RESOLVED', commonResult.status);
System.assertEquals('PT', commonResult.value);
System.assertEquals('Common_Employment_PartTime', commonResult.winner);

MappingRequest overrideRequest = new MappingRequest('ParcelDemo', 'V2', 'EmploymentType', 'Part time');
MappingResult overrideResult = MappingResolver.resolve(overrideRequest);
System.assertEquals('EMP_PART', overrideResult.value);
System.assertEquals('ParcelDemo_V2_Employment_PartTime', overrideResult.winner);
System.assertEquals('PROVIDER_VERSION', overrideResult.layer);
System.assertEquals(false, overrideResult.fallbackUsed);
System.assertEquals(3, overrideResult.shadowedRecords.size());
System.assertEquals(0, MappingResolver.validateSnapshot(MappingRepository.loadSnapshot()).size());

// The whole provider configuration includes shared fallbacks; unrelated providers are excluded.
MappingSnapshot providerConfig = MappingRepository.loadSnapshot(new Set<String>{' ParcelDemo '});
System.assert(providerConfig === MappingRepository.loadSnapshot(new Set<String>{'PARCELDEMO'}));
System.assertEquals(overrideResult.configDigest, providerConfig.configDigest);
Set<String> providerNames = new Set<String>();
for (Value_Mapping__mdt record : providerConfig.getRecords()) { providerNames.add(record.DeveloperName); }
System.assert(providerNames.contains('Common_Employment_PartTime'));
System.assert(providerNames.contains('ParcelDemo_V2_Employment_PartTime'));
MappingSnapshot otherProvider = MappingRepository.loadSnapshot(new Set<String>{'RouteDemo'});
for (Value_Mapping__mdt record : otherProvider.getRecords()) {
    System.assert(String.isBlank(record.Provider_Key__c) || record.Provider_Key__c.equalsIgnoreCase('RouteDemo'));
    System.assertNotEquals('ParcelDemo_V2_Employment_PartTime', record.DeveloperName);
}
System.assertEquals('PT', MappingResolver.resolve(
    new MappingRequest('RouteDemo', null, 'EmploymentType', 'Part time'), otherProvider).value);

MappingRequest missingRequest = new MappingRequest('ParcelDemo', null, 'EmploymentType', 'Contractor');
System.assertEquals('MISSING', MappingResolver.resolve(missingRequest).status);
missingRequest.missingPolicy = 'RETURN_NULL';
MappingResult nullResult = MappingResolver.resolve(missingRequest);
System.assertEquals('MISSING', nullResult.status);
System.assertEquals(null, nullResult.value);
missingRequest.missingPolicy = 'USE_DEFAULT';
missingRequest.defaultValue = 'UNSPECIFIED';
System.assertEquals('UNSPECIFIED', MappingResolver.resolve(missingRequest).value);
Map<String, Map<String, String>> parcelValues = MappingResolver.loadValues('ParcelDemo', 'V2');
System.assertEquals('EMP_PART', parcelValues.get('EmploymentType').get('Part time'));
Map<String, Map<String, String>> routeValues = MappingResolver.loadValues('RouteDemo', 'V2');
System.assertEquals('PART_TIME', routeValues.get('EmploymentType').get('Part time'));
System.assertEquals(null, parcelValues.get('EmploymentType').get('Missing'));
System.debug(LoggingLevel.INFO, 'VALUE_MAPPER_DEMO_PASS ' + JSON.serializePretty(overrideResult));
