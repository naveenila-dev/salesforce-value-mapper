// Compiles the public API and checks precedence without DML or demo dependencies.
List<Value_Mapping__mdt> rows = new List<Value_Mapping__mdt>{
    new Value_Mapping__mdt(DeveloperName='Shared', Mapping_Type__c='Smoke',
        Source_Value__c='input', Target_Value__c='shared', Active__c=true),
    new Value_Mapping__mdt(DeveloperName='Override', Provider_Key__c='ExampleProvider',
        Version_Key__c='V2', Mapping_Type__c='Smoke',
        Source_Value__c='input', Target_Value__c='override', Active__c=true)
};
Map<String, Map<String, String>> mappings = MappingResolver.loadValues('ExampleProvider', 'V2', rows);
System.assertEquals('override', mappings.get('Smoke').get('input'));
System.assertEquals(null, mappings.get('Unknown')?.get('input'));
System.assertEquals('shared', MappingResolver.loadValues(null, null, rows).get('Smoke').get('input'));
List<Value_Mapping__mdt> common = MappingResolver.loadRecords(null);
MappingResolver.loadValues(null, null, common);
System.debug(LoggingLevel.INFO, 'VALUE_MAPPER_SMOKE_PASS');
