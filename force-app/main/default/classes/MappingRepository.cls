/** Transaction-local metadata snapshots. Scoped loads always include common mappings. */
public with sharing class MappingRepository {
    private static MappingSnapshot cached;
    private static Map<String, MappingSnapshot> scoped = new Map<String, MappingSnapshot>();

    /** Explicit whole-org configuration load for audits and validation. */
    public static MappingSnapshot loadSnapshot() {
        if (cached == null) {
            cached = new MappingSnapshot([
                SELECT DeveloperName, Provider_Key__c, Version_Key__c, Mapping_Type__c,
                       Source_Value__c, Target_Value__c, Active__c
                FROM Value_Mapping__mdt
                ORDER BY DeveloperName
            ]);
        }
        return cached;
    }

    /** All types, versions and active/inactive rows for these providers plus common. */
    public static MappingSnapshot loadSnapshot(Set<String> providers) {
        Set<String> normalized = new Set<String>();
        if (providers != null) {
            for (String provider : providers) {
                if (!String.isBlank(provider)) { normalized.add(provider.trim().toLowerCase()); }
            }
        }
        List<String> sorted = new List<String>(normalized);
        sorted.sort();
        String key = JSON.serialize(sorted);
        if (!scoped.containsKey(key)) {
            scoped.put(key, new MappingSnapshot([
                SELECT DeveloperName, Provider_Key__c, Version_Key__c, Mapping_Type__c,
                       Source_Value__c, Target_Value__c, Active__c
                FROM Value_Mapping__mdt
                WHERE Provider_Key__c = null OR Provider_Key__c IN :normalized
                ORDER BY DeveloperName
            ]));
        }
        return scoped.get(key);
    }
}
