@IsTest
private class MappingResolverTest {
    private static Value_Mapping__mdt row(String name, String provider, String version, String source, String target) {
        return new Value_Mapping__mdt(DeveloperName=name, Provider_Key__c=provider,
            Version_Key__c=version, Mapping_Type__c='EmploymentType',
            Source_Value__c=source, Target_Value__c=target, Active__c=true);
    }
    private static List<Value_Mapping__mdt> fixtures() {
        return new List<Value_Mapping__mdt>{
            row('Common', null, null, 'Part time', 'PT'),
            row('CommonV2', null, 'V2', 'Part time', 'PART_TIME'),
            row('Provider', 'ParcelDemo', null, 'Part time', 'P_TIME'),
            row('ProviderV2', 'ParcelDemo', 'V2', 'Part time', 'EMP_PART')
        };
    }
    @IsTest static void precedenceAndNormalization() {
        List<Value_Mapping__mdt> records = fixtures();
        System.assertEquals('PT', MappingResolver.loadValues(null, null, records).get('EmploymentType').get('Part time'));
        System.assertEquals('PART_TIME', MappingResolver.loadValues(null, 'V2', records).get('EmploymentType').get('Part time'));
        System.assertEquals('P_TIME', MappingResolver.loadValues('ParcelDemo', null, records).get('EmploymentType').get('Part time'));
        System.assertEquals('EMP_PART', MappingResolver.loadValues(' ParcelDemo ', ' v2 ', records).get('EmploymentType').get('Part time'));
        System.assertEquals('P_TIME', MappingResolver.loadValues('ParcelDemo', 'V999', records).get('EmploymentType').get('Part time'));
        records.remove(3);
        System.assertEquals('P_TIME', MappingResolver.loadValues('ParcelDemo', 'V2', records).get('EmploymentType').get('Part time'));
        records.add(0, row('OverrideFirst', 'ParcelDemo', 'V2', 'Part time', 'FIRST'));
        System.assertEquals('FIRST', MappingResolver.loadValues('ParcelDemo', 'V2', records).get('EmploymentType').get('Part time'));
    }
    @IsTest static void providerIsolationExactKeysAndInactiveRows() {
        List<Value_Mapping__mdt> records = fixtures();
        records.add(row('Other', 'RouteDemo', 'V2', 'Route only', 'ROUTE'));
        records.add(row('Future', 'ParcelDemo', 'V3', 'Future only', 'FUTURE'));
        records.add(row('Case', null, null, 'part time', 'lower'));
        Value_Mapping__mdt inactive = row('Inactive', null, null, 'Inactive', null);
        inactive.Active__c=false; records.add(inactive);
        Map<String, Map<String, String>> values = MappingResolver.loadValues('ParcelDemo', 'V2', records);
        System.assertEquals('lower', values.get('EmploymentType').get('part time'));
        for (String key : new List<String>{'Route only','Future only','Inactive','Part time ','Missing'}) {
            System.assertEquals(null, values.get('EmploymentType').get(key));
        }
        System.assertEquals(null, values.get('employmenttype')?.get('Part time'));
        System.assertEquals('PART_TIME', MappingResolver.loadValues('Unknown', 'V2', records).get('EmploymentType').get('Part time'));
    }
    @IsTest static void manyCategoriesAndIndependentResults() {
        List<Value_Mapping__mdt> records = new List<Value_Mapping__mdt>();
        for (Integer i=0; i<70; i++) {
            Value_Mapping__mdt record = row('Mapping'+i, i<50 ? 'ParcelDemo' : 'RouteDemo', 'V2', 'X', 'Y'+i);
            record.Mapping_Type__c='Type'+i; records.add(record);
        }
        Map<String, Map<String, String>> parcel = MappingResolver.loadValues('ParcelDemo','V2',records);
        Map<String, Map<String, String>> route = MappingResolver.loadValues('RouteDemo','V2',records);
        System.assertEquals(50, parcel.size()); System.assertEquals(20, route.size());
        for (Integer i=0; i<70; i++) {
            System.assertEquals('Y'+i, (i<50 ? parcel : route).get('Type'+i).get('X'));
        }
        parcel.get('Type0').put('X','changed');
        System.assertEquals('Y0',MappingResolver.loadValues('ParcelDemo','V2',records).get('Type0').get('X'));
        System.assertEquals(0,MappingResolver.loadValues('ParcelDemo',null,records).size());
        System.assertEquals(0,MappingResolver.loadValues(null,null,new List<Value_Mapping__mdt>()).size());
    }
    @IsTest static void invalidAndDuplicateDefinitionsFail() {
        List<Value_Mapping__mdt> duplicate = fixtures();
        duplicate.add(row('Conflict',' parceldemo ',' v2 ','Part time','bad'));
        Value_Mapping__mdt blankType=row('BlankType',null,null,'X','Y'); blankType.Mapping_Type__c=' ';
        for (List<Value_Mapping__mdt> records : new List<List<Value_Mapping__mdt>>{
            null, new List<Value_Mapping__mdt>{null}, duplicate,
            new List<Value_Mapping__mdt>{blankType},
            new List<Value_Mapping__mdt>{row('Empty',null,null,'','Y')},
            new List<Value_Mapping__mdt>{row('Target',null,null,'X',' ')}
        }) {
            Boolean rejected=false;
            try { MappingResolver.loadValues('ParcelDemo','V2',records); }
            catch (MappingResolver.ConfigurationException ex) { rejected=true; }
            System.assert(rejected,'Invalid configuration must not produce a partial map.');
        }
    }
    @IsTest static void compoundKeysCannotCollide() {
        Value_Mapping__mdt a=row('A',null,null,'b|c','A'); a.Mapping_Type__c='a';
        Value_Mapping__mdt b=row('B',null,null,'c','B'); b.Mapping_Type__c='a|b';
        Map<String, Map<String, String>> values=MappingResolver.loadValues(null,null,new List<Value_Mapping__mdt>{a,b});
        System.assertEquals('A',values.get('a').get('b|c'));
        System.assertEquals('B',values.get('a|b').get('c'));
    }
    @IsTest static void liveLoaderFiltersProviderSet() {
        List<Value_Mapping__mdt> rows=MappingResolver.loadRecords(new Set<String>{' ParcelDemo ','ROUTEDEMO',null});
        for (Value_Mapping__mdt record : rows) {
            System.assert(String.isBlank(record.Provider_Key__c) ||
                record.Provider_Key__c.equalsIgnoreCase('ParcelDemo') || record.Provider_Key__c.equalsIgnoreCase('RouteDemo'));
        }
        for (Value_Mapping__mdt record : MappingResolver.loadRecords(null)) {
            System.assert(String.isBlank(record.Provider_Key__c));
        }
        System.assertEquals(MappingResolver.loadValues('ParcelDemo','V2',
            MappingResolver.loadRecords(new Set<String>{'ParcelDemo'})), MappingResolver.loadValues('ParcelDemo','V2'));
    }
}
