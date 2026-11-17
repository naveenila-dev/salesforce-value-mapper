@IsTest
private class MappingResolverTest {
    private static Value_Mapping__mdt row(String name, String provider, String version, String source, String target) {
        return new Value_Mapping__mdt(DeveloperName = name, Provider_Key__c = provider,
            Version_Key__c = version, Mapping_Type__c = 'EmploymentType',
            Source_Value__c = source, Target_Value__c = target, Active__c = true);
    }
    private static List<Value_Mapping__mdt> fixtures() {
        return new List<Value_Mapping__mdt>{
            row('CommonBase', null, null, 'Part time', 'PT'),
            row('CommonV2', null, 'V2', 'Part time', 'PART_TIME'),
            row('ProviderBase', 'ParcelDemo', null, 'Part time', 'P_TIME'),
            row('ProviderV2', 'ParcelDemo', 'V2', 'Part time', 'EMP_PART')
        };
    }
    private static MappingRequest request(String provider, String version) {
        return new MappingRequest(provider, version, 'EmploymentType', 'Part time');
    }
    @IsTest static void allPrecedenceLayersAndExplanation() {
        MappingSnapshot snapshot = new MappingSnapshot(fixtures());
        List<MappingResult> results = MappingResolver.resolveAll(new List<MappingRequest>{
            request(null, null), request(null, 'V2'), request('ParcelDemo', null), request('ParcelDemo', 'V2')
        }, snapshot);
        System.assertEquals(4, results.size());
        System.assertEquals('PT', results[0].value);
        System.assertEquals('COMMON_BASE', results[0].layer);
        System.assertEquals('PART_TIME', results[1].value);
        System.assertEquals('COMMON_VERSION', results[1].layer);
        System.assertEquals('P_TIME', results[2].value);
        System.assertEquals('PROVIDER_BASE', results[2].layer);
        System.assertEquals('EMP_PART', results[3].value);
        System.assertEquals('ProviderV2', results[3].winner);
        System.assertEquals('PROVIDER_VERSION', results[3].layer);
        System.assertEquals(false, results[3].fallbackUsed);
        System.assertEquals(new List<String>{'CommonBase', 'CommonV2', 'ProviderBase'}, results[3].shadowedRecords);
        System.assertEquals(snapshot.configDigest, results[3].configDigest);
        System.assertEquals(0, results[3].issues.size());
    }
    @IsTest static void providerBaseBeatsCommonVersion() {
        List<Value_Mapping__mdt> rows = fixtures(); rows.remove(3);
        MappingResult result = MappingResolver.resolve(request('ParcelDemo', 'V2'), new MappingSnapshot(rows));
        System.assertEquals('P_TIME', result.value);
        System.assertEquals('PROVIDER_BASE', result.layer);
        System.assertEquals(true, result.fallbackUsed);
        System.assertEquals(0, result.issues.size());
    }
    @IsTest static void commonFallbacks() {
        MappingSnapshot snapshot = new MappingSnapshot(fixtures());
        MappingResult versioned = MappingResolver.resolve(request('RouteDemo', 'V2'), snapshot);
        System.assertEquals('PART_TIME', versioned.value);
        System.assertEquals(true, versioned.fallbackUsed);
        MappingResult base = MappingResolver.resolve(request('RouteDemo', null), snapshot);
        System.assertEquals('PT', base.value);
        System.assertEquals(true, base.fallbackUsed);
    }
    @IsTest static void normalizedScopesAndExactInputs() {
        MappingSnapshot snapshot = new MappingSnapshot(fixtures());
        System.assertEquals('EMP_PART', MappingResolver.resolve(request('  pArCeLdEmO ', ' v2 '), snapshot).value);
        MappingRequest r = request('ParcelDemo', 'V2');
        r.sourceValue = 'part time';
        System.assertEquals('MISSING', MappingResolver.resolve(r, snapshot).status);
        r.sourceValue = 'Part time ';
        System.assertEquals('MISSING', MappingResolver.resolve(r, snapshot).status);
        r.sourceValue = 'Part time'; r.mappingType = 'employmenttype';
        System.assertEquals('MISSING', MappingResolver.resolve(r, snapshot).status);
        List<Value_Mapping__mdt> rows = fixtures();
        rows.add(row('LowerCase', null, null, 'part time', 'lower'));
        System.assertEquals(0, MappingResolver.validateSnapshot(new MappingSnapshot(rows)).size());
        r.provider = null; r.version = null; r.mappingType = 'EmploymentType'; r.sourceValue = 'part time';
        System.assertEquals('lower', MappingResolver.resolve(r, new MappingSnapshot(rows)).value);
    }
    @IsTest static void unknownVersionsWarnOrFailStrictly() {
        MappingSnapshot snapshot = new MappingSnapshot(fixtures());
        MappingRequest r = request('ParcelDemo', 'V999');
        MappingResult result = MappingResolver.resolve(r, snapshot);
        System.assertEquals('P_TIME', result.value);
        System.assertEquals(true, result.fallbackUsed);
        System.assertEquals('UNKNOWN_VERSION', result.issues[0].code);
        System.assertEquals('WARNING', result.issues[0].severity);
        r.strictVersion = true; r.missingPolicy = 'USE_DEFAULT'; r.defaultValue = 'DEFAULT';
        result = MappingResolver.resolve(r, snapshot);
        System.assertEquals('INVALID_REQUEST', result.status);
        System.assertEquals(null, result.value);
        System.assertEquals('ERROR', result.issues[0].severity);
    }
    @IsTest static void versionKnowledgeIsScoped() {
        MappingSnapshot snapshot = new MappingSnapshot(new List<Value_Mapping__mdt>{
            row('Base', null, null, 'Part time', 'PT'),
            row('OtherProvider', 'Other', 'V3', 'Part time', 'OTHER'),
            new Value_Mapping__mdt(DeveloperName = 'OtherType', Mapping_Type__c = 'OtherType',
                Version_Key__c = 'V4', Source_Value__c = 'X', Target_Value__c = 'Y', Active__c = true)
        });
        MappingRequest r = request('ParcelDemo', 'V3'); r.strictVersion = true;
        System.assertEquals('INVALID_REQUEST', MappingResolver.resolve(r, snapshot).status);
        r.version = 'V4';
        System.assertEquals('INVALID_REQUEST', MappingResolver.resolve(r, snapshot).status);
    }
    @IsTest static void missingPolicies() {
        MappingSnapshot snapshot = new MappingSnapshot(fixtures());
        MappingRequest r = request(null, null); r.sourceValue = 'Contractor';
        MappingResult result = MappingResolver.resolve(r, snapshot);
        System.assertEquals('MISSING', result.status);
        System.assertEquals('MISSING_MAPPING', result.issues[0].code);
        System.assertEquals(null, result.value);
        r.missingPolicy = 'RETURN_NULL'; result = MappingResolver.resolve(r, snapshot);
        System.assertEquals('MISSING', result.status);
        System.assertEquals(null, result.value);
        System.assertEquals(0, result.issues.size());
        r.missingPolicy = 'USE_DEFAULT'; r.defaultValue = 'UNKNOWN';
        result = MappingResolver.resolve(r, snapshot);
        System.assertEquals('DEFAULTED', result.status);
        System.assertEquals('UNKNOWN', result.value);
        System.assertEquals(true, result.fallbackUsed);
        System.assertEquals(null, result.winner);
    }
    @IsTest static void duplicateConflictsCannotBeHidden() {
        List<Value_Mapping__mdt> rows = fixtures();
        rows.add(row('Conflicting', ' parceldemo ', ' v2 ', 'Part time', 'WRONG'));
        MappingSnapshot snapshot = new MappingSnapshot(rows);
        List<ConfigIssue> issues = MappingResolver.validateSnapshot(snapshot);
        System.assertEquals(1, issues.size());
        System.assertEquals('DUPLICATE_MAPPING', issues[0].code);
        System.assertEquals(new List<String>{'Conflicting', 'ProviderV2'}, issues[0].records);
        MappingRequest r = request('ParcelDemo', 'V2'); r.missingPolicy = 'USE_DEFAULT'; r.defaultValue = 'DEFAULT';
        System.assertEquals('INVALID_CONFIG', MappingResolver.resolve(r, snapshot).status);
        r.sourceValue = 'Unrelated'; r.missingPolicy = 'RETURN_NULL';
        System.assertEquals('INVALID_CONFIG', MappingResolver.resolve(r, snapshot).status);
    }
    @IsTest static void inactiveRecordsAreExcluded() {
        List<Value_Mapping__mdt> rows = fixtures();
        rows[3].Active__c = false;
        Value_Mapping__mdt invalid = new Value_Mapping__mdt(Active__c = false);
        rows.add(invalid);
        MappingSnapshot snapshot = new MappingSnapshot(rows);
        System.assertEquals(0, MappingResolver.validateSnapshot(snapshot).size());
        System.assertEquals('P_TIME', MappingResolver.resolve(request('ParcelDemo', 'V2'), snapshot).value);
    }
    @IsTest static void invalidConfigurationDefinitions() {
        List<Value_Mapping__mdt> rows = new List<Value_Mapping__mdt>{null,
            row(null, null, null, 'X', 'Y'), row('EmptySource', null, null, '', 'Y'),
            row('NullSource', null, null, null, 'Y'), row('BlankTarget', null, null, 'X', ' ')};
        Value_Mapping__mdt invalidType = row('BlankType', null, null, 'X', 'Y');
        invalidType.Mapping_Type__c = ' '; rows.add(invalidType);
        System.assertEquals(6, MappingResolver.validateSnapshot(new MappingSnapshot(rows)).size());
        System.assertEquals('INVALID_CONFIG', MappingResolver.resolve(request(null, null), null).status);
        System.assertEquals('INVALID_CONFIG', MappingResolver.resolve(request(null, null), new MappingSnapshot(null)).status);
        rows = new List<Value_Mapping__mdt>{row('Same', null, null, 'X', 'Y'), row('Same', null, null, 'Z', 'Y')};
        System.assertEquals('DUPLICATE_RECORD_NAME', MappingResolver.validateSnapshot(new MappingSnapshot(rows))[0].code);
    }
    @IsTest static void invalidRequests() {
        MappingSnapshot snapshot = new MappingSnapshot(fixtures());
        System.assertEquals('INVALID_REQUEST', MappingResolver.resolve(null, snapshot).status);
        MappingRequest r = request(null, null);
        r.sourceValue = null;
        System.assertEquals('INVALID_REQUEST', MappingResolver.resolve(r, snapshot).status);
        r.sourceValue = '';
        System.assertEquals('INVALID_REQUEST', MappingResolver.resolve(r, snapshot).status);
        r.sourceValue = 'Part time'; r.mappingType = ' ';
        System.assertEquals('INVALID_REQUEST', MappingResolver.resolve(r, snapshot).status);
        r.mappingType = 'EmploymentType'; r.missingPolicy = 'OTHER';
        System.assertEquals('INVALID_REQUEST', MappingResolver.resolve(r, snapshot).status);
        r.missingPolicy = null;
        System.assertEquals('INVALID_REQUEST', MappingResolver.resolve(r, snapshot).status);
        r.missingPolicy = 'error';
        System.assertEquals('INVALID_REQUEST', MappingResolver.resolve(r, snapshot).status);
        r.missingPolicy = 'USE_DEFAULT'; r.defaultValue = ' ';
        System.assertEquals('INVALID_REQUEST', MappingResolver.resolve(r, snapshot).status);
    }
    @IsTest static void snapshotsAreImmutableAndDigestsStable() {
        List<Value_Mapping__mdt> original = fixtures();
        MappingSnapshot before = new MappingSnapshot(original);
        List<Value_Mapping__mdt> reversed = new List<Value_Mapping__mdt>();
        for (Integer i = original.size() - 1; i >= 0; i--) { reversed.add(original[i]); }
        System.assertEquals(before.configDigest, new MappingSnapshot(reversed).configDigest);
        original[3].Target_Value__c = 'NEW';
        before.getRecords()[3].Target_Value__c = 'MUTATED';
        MappingSnapshot after = new MappingSnapshot(original);
        System.assertNotEquals(before.configDigest, after.configDigest);
        System.assertEquals('EMP_PART', MappingResolver.resolve(request('ParcelDemo', 'V2'), before).value);
        System.assertEquals('NEW', MappingResolver.resolve(request('ParcelDemo', 'V2'), after).value);
        System.assertEquals('EMP_PART', MappingResolver.resolve(request('ParcelDemo', 'V2'), before).value);
    }
    @IsTest static void bulkOrderingAndResultIsolation() {
        List<MappingRequest> requests = new List<MappingRequest>();
        for (Integer i = 0; i < 200; i++) { requests.add(request(i / 2 * 2 == i ? null : 'ParcelDemo', 'V2')); }
        Test.startTest();
        Integer queriesBefore = Limits.getQueries();
        List<MappingResult> results = MappingResolver.resolveAll(requests, new MappingSnapshot(fixtures()));
        System.assertEquals(queriesBefore, Limits.getQueries());
        Test.stopTest();
        System.assertEquals(200, results.size());
        for (Integer i = 0; i < 200; i++) { System.assertEquals(i / 2 * 2 == i ? 'PART_TIME' : 'EMP_PART', results[i].value); }
        results[0].shadowedRecords.clear();
        System.assertEquals(3, results[1].shadowedRecords.size());
        System.assertEquals(0, MappingResolver.resolveAll(null, new MappingSnapshot(fixtures())).size());
        System.assertEquals(0, MappingResolver.resolveAll(new List<MappingRequest>()).size());
        List<Value_Mapping__mdt> bad = fixtures(); bad.add(bad[0]);
        results = MappingResolver.resolveAll(new List<MappingRequest>{request(null, null), request(null, null)}, new MappingSnapshot(bad));
        results[0].issues[0].message = 'changed';
        System.assertNotEquals('changed', results[1].issues[0].message);
    }
    @IsTest static void keysCannotCollide() {
        Value_Mapping__mdt a = row('A', null, null, 'b|c', 'A'); a.Mapping_Type__c = 'a';
        Value_Mapping__mdt b = row('B', null, null, 'c', 'B'); b.Mapping_Type__c = 'a|b';
        MappingSnapshot snapshot = new MappingSnapshot(new List<Value_Mapping__mdt>{a, b});
        System.assertEquals('A', MappingResolver.resolve(new MappingRequest(null, null, 'a', 'b|c'), snapshot).value);
        System.assertEquals('B', MappingResolver.resolve(new MappingRequest(null, null, 'a|b', 'c'), snapshot).value);
        System.assertEquals('MISSING', MappingResolver.resolve(request(null, null), new MappingSnapshot(new List<Value_Mapping__mdt>())).status);
    }
    @IsTest static void repositoryCachesWithinTransaction() {
        Test.startTest();
        MappingSnapshot first = MappingRepository.loadSnapshot();
        Integer queryCount = Limits.getQueries();
        MappingSnapshot second = MappingRepository.loadSnapshot();
        System.assert(first === second, 'Repository must reuse the same snapshot.');
        MappingResult result = MappingResolver.resolve(request('ParcelDemo', 'V2'));
        System.assertEquals(queryCount, Limits.getQueries());
        System.assertEquals(MappingRepository.loadSnapshot(new Set<String>{'ParcelDemo'}).configDigest, result.configDigest);
        // No org-specific result assumption: deterministic fixtures test the contract above.
        Test.stopTest();
    }

    @IsTest static void scopedRepositorySelectsCompleteProviderConfiguration() {
        MappingSnapshot all = MappingRepository.loadSnapshot();
        MappingSnapshot selected = MappingRepository.loadSnapshot(new Set<String>{' ParcelDemo ', 'ROUTEDEMO', null});
        List<Value_Mapping__mdt> expected = new List<Value_Mapping__mdt>();
        for (Value_Mapping__mdt record : all.getRecords()) {
            if (String.isBlank(record.Provider_Key__c) ||
                record.Provider_Key__c.trim().equalsIgnoreCase('ParcelDemo') ||
                record.Provider_Key__c.trim().equalsIgnoreCase('RouteDemo')) {
                expected.add(record);
            }
        }
        System.assertEquals(new MappingSnapshot(expected).configDigest, selected.configDigest);
        System.assert(selected === MappingRepository.loadSnapshot(new Set<String>{'routedemo', 'parceldemo'}),
            'Order, case, whitespace and blank entries must not split the cache.');
        List<Value_Mapping__mdt> common = new List<Value_Mapping__mdt>();
        for (Value_Mapping__mdt record : all.getRecords()) {
            if (String.isBlank(record.Provider_Key__c)) { common.add(record); }
        }
        MappingSnapshot commonOnly = MappingRepository.loadSnapshot(new Set<String>());
        System.assertEquals(new MappingSnapshot(common).configDigest, commonOnly.configDigest);
        System.assert(commonOnly === MappingRepository.loadSnapshot(null));
        System.assert(commonOnly === MappingRepository.loadSnapshot(new Set<String>{null, ' '}));
        System.assertEquals(commonOnly.configDigest,
            MappingResolver.resolve(new MappingRequest(null, null, 'EmploymentType', 'Part time')).configDigest);
        System.assertEquals(MappingRepository.loadSnapshot(new Set<String>{'ParcelDemo'}).configDigest,
            MappingResolver.resolve(request(' ParcelDemo ', 'V2')).configDigest);
        List<MappingResult> batch = MappingResolver.resolveAll(new List<MappingRequest>{
            request('ParcelDemo', 'V2'), request('RouteDemo', null), null
        });
        System.assertEquals(3, batch.size());
        for (MappingResult result : batch) { System.assertEquals(selected.configDigest, result.configDigest); }
    }

    @IsTest static void nestedValuesApplyTheSamePrecedenceAndFallbacks() {
        List<Value_Mapping__mdt> rows = fixtures();
        rows.add(row('OtherProvider', 'RouteDemo', 'V2', 'Other only', 'OTHER'));
        rows.add(row('OtherVersion', 'ParcelDemo', 'V3', 'Future only', 'FUTURE'));
        Value_Mapping__mdt inactive = row('Inactive', 'ParcelDemo', 'V2', 'Inactive', 'NO');
        inactive.Active__c = false; rows.add(inactive);
        rows.add(row('ExactCase', null, null, 'part time', 'lower'));
        MappingSnapshot snapshot = new MappingSnapshot(rows);
        Map<String, Map<String, String>> values = MappingResolver.loadValues(' ParcelDemo ', ' v2 ', snapshot);
        System.assertEquals('EMP_PART', values.get('EmploymentType').get('Part time'));
        System.assertEquals('lower', values.get('EmploymentType').get('part time'));
        System.assertEquals(null, values.get('employmenttype'));
        for (String source : new List<String>{'Other only', 'Future only', 'Inactive', 'Missing'}) {
            System.assertEquals(null, values.get('EmploymentType').get(source));
        }
        for (String provider : new List<String>{null, 'ParcelDemo', 'RouteDemo'}) {
            for (String version : new List<String>{null, 'V2', 'V999'}) {
                Map<String, Map<String, String>> effective = MappingResolver.loadValues(provider, version, snapshot);
                for (String type : effective.keySet()) {
                    for (String source : effective.get(type).keySet()) {
                        System.assertEquals(MappingResolver.resolve(
                            new MappingRequest(provider, version, type, source), snapshot).value,
                            effective.get(type).get(source));
                    }
                }
            }
        }
        System.assertEquals('P_TIME', MappingResolver.loadValues('ParcelDemo', 'V999', snapshot)
            .get('EmploymentType').get('Part time'));
        rows.remove(3);
        System.assertEquals('P_TIME', MappingResolver.loadValues('ParcelDemo', 'V2', new MappingSnapshot(rows))
            .get('EmploymentType').get('Part time'), 'Provider base overrides common version.');
    }

    @IsTest static void nestedValuesSupportManyCategoriesAndCallerOwnedMaps() {
        List<Value_Mapping__mdt> rows = new List<Value_Mapping__mdt>();
        for (Integer i=0; i<70; i++) {
            Value_Mapping__mdt record = row('Mapping'+i, i<50 ? 'ParcelDemo' : 'RouteDemo', 'V2', 'X', 'Y'+i);
            record.Mapping_Type__c = 'Type'+i; rows.add(record);
        }
        MappingSnapshot snapshot = new MappingSnapshot(rows);
        Map<String, Map<String, String>> parcel = MappingResolver.loadValues('ParcelDemo', 'V2', snapshot);
        Map<String, Map<String, String>> route = MappingResolver.loadValues('RouteDemo', 'V2', snapshot);
        System.assertEquals(50, parcel.size());
        System.assertEquals(20, route.size());
        for (Integer i=0; i<70; i++) {
            System.assertEquals('Y'+i, (i<50 ? parcel : route).get('Type'+i).get('X'));
        }
        parcel.get('Type0').put('X', 'MUTATED');
        System.assertEquals('Y0', MappingResolver.loadValues('ParcelDemo', 'V2', snapshot).get('Type0').get('X'));
        System.assertEquals(0, MappingResolver.loadValues('ParcelDemo', null, snapshot).size());
        System.assertEquals(0, MappingResolver.loadValues('Unknown', 'V2', snapshot).size());
        System.assertEquals(0, MappingResolver.loadValues(null, null,
            new MappingSnapshot(new List<Value_Mapping__mdt>())).size());
    }

    @IsTest static void nestedValuesRejectInvalidConfigurationBeforeReturningValues() {
        List<Value_Mapping__mdt> duplicate = fixtures(); duplicate.add(duplicate[0]);
        for (MappingSnapshot snapshot : new List<MappingSnapshot>{
            null, new MappingSnapshot(null), new MappingSnapshot(duplicate)
        }) {
            Boolean rejected = false;
            try { MappingResolver.loadValues('ParcelDemo', 'V2', snapshot); }
            catch (MappingResolver.ConfigurationException ex) {
                rejected = true;
                System.assert(ex.getMessage().contains('Invalid mapping configuration'));
            }
            System.assert(rejected, 'Never return a partial map for invalid configuration.');
        }
    }

    @IsTest static void nestedValuesUseProviderScopedRepository() {
        MappingSnapshot snapshot = MappingRepository.loadSnapshot(new Set<String>{'ParcelDemo'});
        if (MappingResolver.validateSnapshot(snapshot).isEmpty()) {
            System.assertEquals(MappingResolver.loadValues('ParcelDemo', 'V2', snapshot),
                MappingResolver.loadValues(' ParcelDemo ', ' v2 '));
        } else {
            Boolean rejected = false;
            try { MappingResolver.loadValues('ParcelDemo', 'V2'); }
            catch (MappingResolver.ConfigurationException ex) { rejected = true; }
            System.assert(rejected);
        }
    }
}