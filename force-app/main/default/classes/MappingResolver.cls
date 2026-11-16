/** Deterministic string mapper. Any invalid active configuration invalidates the snapshot. */
public with sharing class MappingResolver {
    private static final List<String> LAYERS = new List<String>{
        'COMMON_BASE', 'COMMON_VERSION', 'PROVIDER_BASE', 'PROVIDER_VERSION'
    };

    private class Prepared {
        Map<String, Value_Mapping__mdt> index = new Map<String, Value_Mapping__mdt>();
        Set<String> versions = new Set<String>();
        List<ConfigIssue> issues = new List<ConfigIssue>();
        String digest;
    }

    public static MappingResult resolve(MappingRequest request) {
        return resolveAll(new List<MappingRequest>{request})[0];
    }

    public static MappingResult resolve(MappingRequest request, MappingSnapshot snapshot) {
        return resolveAll(new List<MappingRequest>{request}, snapshot)[0];
    }

    public static List<MappingResult> resolveAll(List<MappingRequest> requests) {
        return resolveAll(requests, MappingRepository.loadSnapshot());
    }

    public static List<MappingResult> resolveAll(List<MappingRequest> requests, MappingSnapshot snapshot) {
        List<MappingResult> results = new List<MappingResult>();
        if (requests == null || requests.isEmpty()) { return results; }
        Prepared prepared = prepare(snapshot);
        for (MappingRequest request : requests) { results.add(resolvePrepared(request, prepared)); }
        return results;
    }

    public static List<ConfigIssue> validateSnapshot(MappingSnapshot snapshot) {
        return prepare(snapshot).issues;
    }

    private static Prepared prepare(MappingSnapshot snapshot) {
        Prepared p = new Prepared();
        if (snapshot == null) {
            p.issues.add(issue('INVALID_SNAPSHOT', 'ERROR', 'A snapshot is required.', null));
            return p;
        }
        p.digest = snapshot.configDigest;
        Map<String, List<String>> identities = new Map<String, List<String>>();
        Set<String> names = new Set<String>();
        List<Value_Mapping__mdt> rows = snapshot.getRecords();
        for (Value_Mapping__mdt row : rows) {
            if (row == null) {
                p.issues.add(issue('INVALID_RECORD', 'ERROR', 'A snapshot contains a null record.', null));
                continue;
            }
            if (row.Active__c != true) { continue; }
            List<String> recordNames = new List<String>{row.DeveloperName};
            if (String.isBlank(row.DeveloperName) || String.isBlank(row.Mapping_Type__c) ||
                row.Source_Value__c == null || row.Source_Value__c.length() == 0 ||
                String.isBlank(row.Target_Value__c)) {
                p.issues.add(issue('INVALID_RECORD', 'ERROR',
                    'Active records require an identifier, mapping type, nonempty source and nonblank target.', recordNames));
                continue;
            }
            if (names.contains(row.DeveloperName)) {
                p.issues.add(issue('DUPLICATE_RECORD_NAME', 'ERROR', 'Record identifiers must be unique.', recordNames));
            }
            names.add(row.DeveloperName);
            String provider = normalizeProvider(row.Provider_Key__c);
            String version = normalizeVersion(row.Version_Key__c);
            String key = identity(provider, version, row.Mapping_Type__c, row.Source_Value__c);
            if (!identities.containsKey(key)) { identities.put(key, new List<String>()); }
            identities.get(key).add(row.DeveloperName);
            p.index.put(key, row);
            if (version != '') { p.versions.add(versionIdentity(provider, version, row.Mapping_Type__c)); }
        }
        List<String> keys = new List<String>(identities.keySet());
        keys.sort();
        for (String key : keys) {
            List<String> conflicting = identities.get(key);
            if (conflicting.size() > 1) {
                conflicting.sort();
                p.issues.add(issue('DUPLICATE_MAPPING', 'ERROR',
                    'Multiple active records define the same normalized mapping.', conflicting));
            }
        }
        return p;
    }

    private static MappingResult resolvePrepared(MappingRequest request, Prepared p) {
        MappingResult result = new MappingResult();
        result.configDigest = p.digest;
        // Policies can never conceal a broken snapshot, even for unrelated source values.
        if (!p.issues.isEmpty()) {
            result.status = 'INVALID_CONFIG';
            result.issues = (List<ConfigIssue>) JSON.deserialize(JSON.serialize(p.issues), List<ConfigIssue>.class);
            return result;
        }
        if (request == null || String.isBlank(request.mappingType) ||
            request.sourceValue == null || request.sourceValue.length() == 0 ||
            request.missingPolicy == null ||
            !(request.missingPolicy.equals('ERROR') || request.missingPolicy.equals('RETURN_NULL') ||
              request.missingPolicy.equals('USE_DEFAULT')) ||
            (request.missingPolicy.equals('USE_DEFAULT') && String.isBlank(request.defaultValue))) {
            result.status = 'INVALID_REQUEST';
            result.issues.add(issue('INVALID_REQUEST', 'ERROR',
                'Supply a mapping type, nonempty source, valid missing policy and nonblank default for USE_DEFAULT.', null));
            return result;
        }
        String provider = normalizeProvider(request.provider);
        String version = normalizeVersion(request.version);
        if (version != '' && !p.versions.contains(versionIdentity('', version, request.mappingType)) &&
            !p.versions.contains(versionIdentity(provider, version, request.mappingType))) {
            Boolean strict = request.strictVersion == true;
            result.issues.add(issue('UNKNOWN_VERSION', strict ? 'ERROR' : 'WARNING',
                'No active mapping defines the requested version for this provider/common scope and mapping type.', null));
            if (strict) { result.status = 'INVALID_REQUEST'; return result; }
            result.fallbackUsed = true;
        }
        List<String> providers = new List<String>{'', '', provider, provider};
        List<String> versions = new List<String>{'', version, '', version};
        Integer highest = provider == '' ? (version == '' ? 0 : 1) : (version == '' ? 2 : 3);
        Integer winningLayer;
        for (Integer i = 0; i < 4; i++) {
            if ((i == 1 && version == '') || (i >= 2 && provider == '') || (i == 3 && version == '')) { continue; }
            Value_Mapping__mdt row = p.index.get(identity(providers[i], versions[i], request.mappingType, request.sourceValue));
            if (row != null) {
                if (result.winner != null) { result.shadowedRecords.add(result.winner); }
                result.winner = row.DeveloperName;
                result.value = row.Target_Value__c;
                result.layer = LAYERS[i];
                winningLayer = i;
            }
        }
        if (result.winner != null) {
            result.status = 'RESOLVED';
            result.fallbackUsed = result.fallbackUsed || winningLayer < highest;
            return result;
        }
        result.status = 'MISSING';
        if (request.missingPolicy.equals('USE_DEFAULT')) {
            result.status = 'DEFAULTED';
            result.value = request.defaultValue;
            result.fallbackUsed = true;
        } else if (request.missingPolicy.equals('ERROR')) {
            result.issues.add(issue('MISSING_MAPPING', 'ERROR', 'No mapping matches the requested input.', null));
        }
        return result;
    }

    private static String normalizeProvider(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }
    private static String normalizeVersion(String value) {
        return String.isBlank(value) ? '' : value.trim().toUpperCase();
    }
    // JSON arrays avoid collisions from delimiters embedded in exact input strings.
    private static String identity(String provider, String version, String mappingType, String source) {
        return JSON.serialize(new List<String>{provider, version, mappingType, source});
    }
    private static String versionIdentity(String provider, String version, String mappingType) {
        return JSON.serialize(new List<String>{provider, version, mappingType});
    }
    private static ConfigIssue issue(String code, String severity, String message, List<String> records) {
        return new ConfigIssue(code, severity, message, records);
    }
}
