/** Immutable, caller-owned copy. Retain records as well as digest to reproduce a run. */
public class MappingSnapshot {
    private List<Value_Mapping__mdt> entries;
    public String configDigest { get; private set; }

    public MappingSnapshot(List<Value_Mapping__mdt> records) {
        entries = new List<Value_Mapping__mdt>();
        List<String> canonical = new List<String>();
        if (records == null) {
            entries.add(null);
            canonical.add('null');
        } else {
            for (Value_Mapping__mdt row : records) {
                entries.add(row == null ? null : row.clone(false, true, false, false));
                canonical.add(row == null ? 'null' : JSON.serialize(new List<Object>{
                    row.DeveloperName, row.Provider_Key__c, row.Version_Key__c,
                    row.Mapping_Type__c, row.Source_Value__c, row.Target_Value__c, row.Active__c
                }));
            }
        }
        canonical.sort();
        configDigest = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256',
            Blob.valueOf(JSON.serialize(canonical))));
    }

    public List<Value_Mapping__mdt> getRecords() {
        List<Value_Mapping__mdt> copy = new List<Value_Mapping__mdt>();
        for (Value_Mapping__mdt row : entries) {
            copy.add(row == null ? null : row.clone(false, true, false, false));
        }
        return copy;
    }
}
