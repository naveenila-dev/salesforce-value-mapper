// Works with an empty installation or customer mappings; no demo records required.
MappingSnapshot installed = MappingRepository.loadSnapshot();
List<ConfigIssue> issues = MappingResolver.validateSnapshot(installed);
System.assertEquals(0, issues.size(), 'Invalid installed configuration: ' + JSON.serialize(issues));
System.assertEquals(0, MappingResolver.resolveAll(new List<MappingRequest>()).size());

// Exercise resolution without adding records or depending on customer values.
MappingSnapshot fixture = new MappingSnapshot(new List<Value_Mapping__mdt>{
    new Value_Mapping__mdt(DeveloperName = 'Smoke_Common', Mapping_Type__c = 'Smoke',
        Source_Value__c = 'input', Target_Value__c = 'shared', Active__c = true),
    new Value_Mapping__mdt(DeveloperName = 'Smoke_Override', Mapping_Type__c = 'Smoke',
        Provider_Key__c = 'ExampleProvider', Version_Key__c = 'V2',
        Source_Value__c = 'input', Target_Value__c = 'override', Active__c = true)
});
MappingRequest request = new MappingRequest('ExampleProvider', 'V2', 'Smoke', 'input');
MappingResult result = MappingResolver.resolve(request, fixture);
System.assertEquals('RESOLVED', result.status);
System.assertEquals('override', result.value);
System.assertEquals('Smoke_Override', result.winner);
System.assertEquals('PROVIDER_VERSION', result.layer);
System.assertEquals('shared', MappingResolver.resolve(new MappingRequest(null, null, 'Smoke', 'input'), fixture).value);
request.sourceValue = 'missing';
System.assertEquals('MISSING', MappingResolver.resolve(request, fixture).status);
request.missingPolicy = 'RETURN_NULL';
System.assertEquals(null, MappingResolver.resolve(request, fixture).value);
request.missingPolicy = 'USE_DEFAULT';
request.defaultValue = 'default';
System.assertEquals('default', MappingResolver.resolve(request, fixture).value);
System.debug(LoggingLevel.INFO, 'VALUE_MAPPER_SMOKE_PASS installedConfigDigest=' + installed.configDigest);
