/** Load once per integration, then use mappings.get(type)?.get(source). */
public with sharing class MappingResolver {
    public class ConfigurationException extends Exception {}

    public static Map<String, Map<String, String>> loadValues(String provider, String version) {
        return loadValues(provider, version, loadRecords(new Set<String>{provider}));
    }

    /** All configuration for the supplied providers plus common mappings. No DML. */
    public static List<Value_Mapping__mdt> loadRecords(Set<String> providers) {
        Set<String> keys = new Set<String>();
        if (providers != null) {
            for (String provider : providers) { keys.add(normalize(provider)); }
        }
        return [
            SELECT DeveloperName, Provider_Key__c, Version_Key__c, Mapping_Type__c,
                   Source_Value__c, Target_Value__c, Active__c
            FROM Value_Mapping__mdt
            WHERE Provider_Key__c = null OR Provider_Key__c IN :keys
            ORDER BY DeveloperName
        ];
    }

    /** Also accepts preloaded records, for bulk callers and tests. */
    public static Map<String, Map<String, String>> loadValues(
        String provider, String version, List<Value_Mapping__mdt> records
    ) {
        if (records == null) { throw new ConfigurationException('Mapping records are required.'); }
        String providerKey = normalize(provider);
        String versionKey = normalize(version);
        Map<String, Map<String, String>> values = new Map<String, Map<String, String>>();
        Map<String, Integer> priorities = new Map<String, Integer>();
        Set<String> identities = new Set<String>();
        for (Value_Mapping__mdt row : records) {
            if (row == null) { throw new ConfigurationException('A mapping record is null.'); }
            if (row.Active__c != true) { continue; }
            String rowProvider = normalize(row.Provider_Key__c);
            String rowVersion = normalize(row.Version_Key__c);
            if ((rowProvider != '' && rowProvider != providerKey) ||
                (rowVersion != '' && rowVersion != versionKey)) { continue; }
            if (String.isBlank(row.Mapping_Type__c) || String.isEmpty(row.Source_Value__c) ||
                String.isBlank(row.Target_Value__c)) {
                throw new ConfigurationException('Invalid mapping: ' + row.DeveloperName);
            }
            String identity = JSON.serialize(new List<String>{
                rowProvider, rowVersion, row.Mapping_Type__c, row.Source_Value__c
            });
            if (identities.contains(identity)) {
                throw new ConfigurationException('Duplicate mapping: ' + row.DeveloperName);
            }
            identities.add(identity);
            String key = JSON.serialize(new List<String>{row.Mapping_Type__c, row.Source_Value__c});
            Integer priority = (rowProvider == '' ? 0 : 2) + (rowVersion == '' ? 0 : 1);
            if (!priorities.containsKey(key) || priority > priorities.get(key)) {
                if (!values.containsKey(row.Mapping_Type__c)) {
                    values.put(row.Mapping_Type__c, new Map<String, String>());
                }
                values.get(row.Mapping_Type__c).put(row.Source_Value__c, row.Target_Value__c);
                priorities.put(key, priority);
            }
        }
        return values;
    }

    private static String normalize(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }
}
