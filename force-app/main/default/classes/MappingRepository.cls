/** One metadata query per transaction; resolution performs no DML or callouts. */
public with sharing class MappingRepository {
    private static MappingSnapshot cached;

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
}
