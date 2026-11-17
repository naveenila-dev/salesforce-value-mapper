@IsTest
private class MappingFlowActionTest {
    private static MappingFlowAction.Input input(String provider, String version, String source) {
        MappingFlowAction.Input value = new MappingFlowAction.Input();
        value.provider = provider;
        value.version = version;
        value.mappingType = 'EmploymentType';
        value.sourceValue = source;
        return value;
    }

    private static MappingSnapshot fixture() {
        return new MappingSnapshot(new List<Value_Mapping__mdt>{
            new Value_Mapping__mdt(DeveloperName='Shared', Mapping_Type__c='EmploymentType',
                Source_Value__c='Part time', Target_Value__c='PT', Active__c=true),
            new Value_Mapping__mdt(DeveloperName='Override', Provider_Key__c='ParcelDemo',
                Version_Key__c='V2', Mapping_Type__c='EmploymentType',
                Source_Value__c='Part time', Target_Value__c='EMP_PART', Active__c=true)
        });
    }

    @IsTest static void bulkResultsPreserveInterviewOrderAndProvenance() {
        List<MappingFlowAction.Input> inputs = new List<MappingFlowAction.Input>();
        for (Integer i=0; i<200; i++) {
            inputs.add(input(Math.mod(i, 2)==0 ? null : ' ParcelDemo ', 'V2', 'Part time'));
        }
        MappingSnapshot snapshot = fixture();
        Test.startTest();
        Integer dmlBefore = Limits.getDmlStatements();
        List<MappingFlowAction.Output> outputs = MappingFlowAction.resolve(inputs, snapshot);
        System.assertEquals(dmlBefore, Limits.getDmlStatements());
        Test.stopTest();
        System.assertEquals(200, outputs.size());
        for (Integer i=0; i<200; i++) {
            MappingFlowAction.Output output = outputs[i];
            System.assertEquals('RESOLVED', output.status);
            System.assertEquals(Math.mod(i, 2)==0 ? 'PT' : 'EMP_PART', output.value);
            System.assertEquals(Math.mod(i, 2)==0 ? 'Shared' : 'Override', output.winner);
            System.assertEquals(Math.mod(i, 2)==0 ? 'COMMON_BASE' : 'PROVIDER_VERSION', output.layer);
            System.assertEquals(Math.mod(i, 2)==0, output.fallbackUsed);
            System.assertEquals(snapshot.configDigest, output.configDigest);
            System.assertEquals(false, output.hasErrors);
        }
        System.assertEquals(new List<String>{'Shared'}, outputs[1].shadowedRecords);
        System.assertEquals('[]', outputs[1].issuesJson);
    }

    @IsTest static void policiesDefaultsAndInvalidInputsRemainPerInterview() {
        MappingFlowAction.Input missing = input(null, null, 'Unknown');
        MappingFlowAction.Input nullable = input(null, null, 'Unknown');
        nullable.missingPolicy = 'RETURN_NULL';
        MappingFlowAction.Input defaulted = input(null, null, 'Unknown');
        defaulted.missingPolicy = 'USE_DEFAULT'; defaulted.defaultValue = 'OTHER';
        MappingFlowAction.Input invalid = input(null, null, 'Part time');
        invalid.missingPolicy = 'error';
        MappingFlowAction.Input blankPolicy = input(null, null, 'Unknown'); blankPolicy.missingPolicy = ' ';
        MappingFlowAction.Input invalidDefault = input(null, null, 'Part time');
        invalidDefault.missingPolicy = 'USE_DEFAULT';
        List<MappingFlowAction.Output> outputs = MappingFlowAction.resolve(new List<MappingFlowAction.Input>{
            missing, nullable, defaulted, invalid, null, blankPolicy, invalidDefault
        }, fixture());
        System.assertEquals(7, outputs.size());
        System.assertEquals('MISSING', outputs[0].status);
        System.assertEquals(true, outputs[0].hasErrors);
        System.assertEquals(new List<String>{'MISSING_MAPPING'}, outputs[0].issueCodes);
        System.assertEquals(1, outputs[0].issueMessages.size());
        System.assertEquals(null, outputs[1].value);
        System.assertEquals('MISSING', outputs[1].status);
        System.assertEquals(false, outputs[1].hasErrors);
        System.assertEquals('[]', outputs[1].issuesJson);
        System.assertEquals('DEFAULTED', outputs[2].status);
        System.assertEquals('OTHER', outputs[2].value);
        System.assertEquals(true, outputs[2].fallbackUsed);
        System.assertEquals(false, outputs[2].hasErrors);
        for (Integer i : new List<Integer>{3, 4, 6}) {
            System.assertEquals('INVALID_REQUEST', outputs[i].status);
            System.assertEquals(true, outputs[i].hasErrors);
        }
        System.assertEquals(true, outputs[5].hasErrors);
        System.assertEquals('MISSING_MAPPING', outputs[5].issueCodes[0]);
    }

    @IsTest static void versionWarningsAndErrorsAreExposed() {
        MappingFlowAction.Input lenient = input('ParcelDemo', 'V999', 'Part time');
        MappingFlowAction.Input strict = input('ParcelDemo', 'V999', 'Part time'); strict.strictVersion = true;
        List<MappingFlowAction.Output> outputs = MappingFlowAction.resolve(
            new List<MappingFlowAction.Input>{lenient, strict}, fixture());
        System.assertEquals('PT', outputs[0].value);
        System.assertEquals(true, outputs[0].fallbackUsed);
        System.assertEquals(false, outputs[0].hasErrors);
        System.assertEquals(new List<String>{'UNKNOWN_VERSION'}, outputs[0].issueCodes);
        List<ConfigIssue> issues = (List<ConfigIssue>)JSON.deserialize(outputs[0].issuesJson, List<ConfigIssue>.class);
        System.assertEquals('WARNING', issues[0].severity);
        System.assertEquals('INVALID_REQUEST', outputs[1].status);
        System.assertEquals(true, outputs[1].hasErrors);
    }

    @IsTest static void invalidConfigurationDoesNotFaultOrLoseResults() {
        List<Value_Mapping__mdt> records = fixture().getRecords(); records.add(records[0]);
        List<MappingFlowAction.Output> outputs = MappingFlowAction.resolve(new List<MappingFlowAction.Input>{
            input(null, null, 'Part time'), input('ParcelDemo', 'V2', 'Part time')
        }, new MappingSnapshot(records));
        System.assertEquals(2, outputs.size());
        for (MappingFlowAction.Output output : outputs) {
            System.assertEquals('INVALID_CONFIG', output.status);
            System.assertEquals(true, output.hasErrors);
            System.assert(output.issueCodes.contains('DUPLICATE_MAPPING'));
            System.assertEquals(null, output.value);
        }
        outputs[0].issueCodes.clear();
        System.assert(!outputs[1].issueCodes.isEmpty());
    }

    @IsTest static void publicActionUsesScopedRepositoryAndHandlesEmptyBatches() {
        System.assertEquals(0, MappingFlowAction.resolve(null).size());
        System.assertEquals(0, MappingFlowAction.resolve(new List<MappingFlowAction.Input>()).size());
        List<MappingFlowAction.Input> inputs = new List<MappingFlowAction.Input>{
            input('ParcelDemo', 'V2', 'Part time'), input('RouteDemo', null, 'Part time'), null
        };
        List<MappingResult> expected = MappingResolver.resolveAll(new List<MappingRequest>{
            new MappingRequest('ParcelDemo', 'V2', 'EmploymentType', 'Part time'),
            new MappingRequest('RouteDemo', null, 'EmploymentType', 'Part time'), null
        });
        List<MappingFlowAction.Output> actual = MappingFlowAction.resolve(inputs);
        System.assertEquals(expected.size(), actual.size());
        for (Integer i=0; i<actual.size(); i++) {
            System.assertEquals(expected[i].status, actual[i].status);
            System.assertEquals(expected[i].value, actual[i].value);
            System.assertEquals(expected[i].configDigest, actual[i].configDigest);
            System.assertEquals(JSON.serialize(expected[i].issues), actual[i].issuesJson);
        }
    }
}
