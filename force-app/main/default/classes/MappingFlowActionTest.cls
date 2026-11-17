@IsTest
private class MappingFlowActionTest {
    private static MappingFlowAction.Input input(String provider, String version, String source) {
        MappingFlowAction.Input value=new MappingFlowAction.Input();
        value.provider=provider; value.version=version;
        value.mappingType='EmploymentType'; value.sourceValue=source; return value;
    }
    @IsTest static void bulkOrderSharedFallbackAndMissingValues() {
        List<Value_Mapping__mdt> rows=new List<Value_Mapping__mdt>{
            new Value_Mapping__mdt(DeveloperName='Common', Mapping_Type__c='EmploymentType',
                Source_Value__c='Part time',Target_Value__c='PT',Active__c=true),
            new Value_Mapping__mdt(DeveloperName='Provider',Provider_Key__c='ParcelDemo',Version_Key__c='V2',
                Mapping_Type__c='EmploymentType',Source_Value__c='Part time',Target_Value__c='EMP_PART',Active__c=true)
        };
        List<MappingFlowAction.Input> inputs=new List<MappingFlowAction.Input>();
        for (Integer i=0; i<200; i++) {
            inputs.add(input(Math.mod(i,2)==0 ? 'ParcelDemo' : 'RouteDemo','V2','Part time'));
        }
        List<MappingFlowAction.Output> outputs=MappingFlowAction.resolve(inputs,rows);
        System.assertEquals(200,outputs.size());
        for (Integer i=0; i<200; i++) {
            System.assertEquals(Math.mod(i,2)==0 ? 'EMP_PART' : 'PT',outputs[i].value);
            System.assertEquals(true,outputs[i].found);
        }
        MappingFlowAction.Input missingType=input(null,null,'Part time'); missingType.mappingType='Unknown';
        outputs=MappingFlowAction.resolve(new List<MappingFlowAction.Input>{input(null,null,'Missing'),missingType},rows);
        for (MappingFlowAction.Output output : outputs) {
            System.assertEquals(null,output.value); System.assertEquals(false,output.found);
        }
    }
    @IsTest static void invalidInputAndConfigFault() {
        for (MappingFlowAction.Input value : new List<MappingFlowAction.Input>{null,input(null,null,null)}) {
            Boolean rejected=false;
            try { MappingFlowAction.resolve(new List<MappingFlowAction.Input>{value},new List<Value_Mapping__mdt>()); }
            catch (MappingResolver.ConfigurationException ex) { rejected=true; }
            System.assert(rejected);
        }
        Boolean rejected=false;
        try { MappingFlowAction.resolve(new List<MappingFlowAction.Input>{input(null,null,'Part time')},
            new List<Value_Mapping__mdt>{new Value_Mapping__mdt(Active__c=true)}); }
        catch (MappingResolver.ConfigurationException ex) { rejected=true; }
        System.assert(rejected);
    }
    @IsTest static void publicActionLoadsConfigurationOnceForBulkInputs() {
        System.assertEquals(0,MappingFlowAction.resolve(null).size());
        System.assertEquals(0,MappingFlowAction.resolve(new List<MappingFlowAction.Input>()).size());
        List<MappingFlowAction.Output> outputs=MappingFlowAction.resolve(new List<MappingFlowAction.Input>{
            input('ParcelDemo','V2','Part time'),input('RouteDemo',null,'Part time')
        });
        System.assertEquals(2,outputs.size());
        System.assertEquals(MappingResolver.loadValues('ParcelDemo','V2').get('EmploymentType')?.get('Part time'),outputs[0].value);
        System.assertEquals(MappingResolver.loadValues('RouteDemo',null).get('EmploymentType')?.get('Part time'),outputs[1].value);
    }
}
