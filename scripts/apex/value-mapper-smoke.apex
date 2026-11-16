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

MappingRequest missingRequest = new MappingRequest('ParcelDemo', null, 'EmploymentType', 'Contractor');
System.assertEquals('MISSING', MappingResolver.resolve(missingRequest).status);
missingRequest.missingPolicy = 'RETURN_NULL';
MappingResult nullResult = MappingResolver.resolve(missingRequest);
System.assertEquals('MISSING', nullResult.status);
System.assertEquals(null, nullResult.value);
missingRequest.missingPolicy = 'USE_DEFAULT';
missingRequest.defaultValue = 'UNSPECIFIED';
System.assertEquals('UNSPECIFIED', MappingResolver.resolve(missingRequest).value);
System.debug(LoggingLevel.INFO, 'VALUE_MAPPER_SMOKE_PASS ' + JSON.serializePretty(overrideResult));
