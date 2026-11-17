/** One ordered output per Flow interview; one metadata load per invocation. */
public with sharing class MappingFlowAction {
    public class Input {
        @InvocableVariable(label='Provider')
        public String provider;
        @InvocableVariable(label='Version')
        public String version;
        @InvocableVariable(label='Mapping Type' required=true)
        public String mappingType;
        @InvocableVariable(label='Source Value' required=true)
        public String sourceValue;
        public Input() {}
    }

    public class Output {
        @InvocableVariable(label='Mapped Value')
        public String value;
        @InvocableVariable(label='Found')
        public Boolean found;
        public Output() {}
    }

    @InvocableMethod(label='Resolve Value Mappings' description='Look up values using provider/version mappings and shared fallbacks.' category='Value Mapper')
    public static List<Output> resolve(List<Input> inputs) {
        if (inputs == null || inputs.isEmpty()) { return new List<Output>(); }
        Set<String> providers = new Set<String>();
        for (Input input : inputs) {
            if (input != null) { providers.add(input.provider); }
        }
        return resolve(inputs, MappingResolver.loadRecords(providers));
    }

    @TestVisible
    private static List<Output> resolve(List<Input> inputs, List<Value_Mapping__mdt> records) {
        Map<String, Map<String, Map<String, String>>> scopes = new Map<String, Map<String, Map<String, String>>>();
        List<Output> outputs = new List<Output>();
        for (Input input : inputs) {
            if (input == null || String.isBlank(input.mappingType) || String.isEmpty(input.sourceValue)) {
                throw new MappingResolver.ConfigurationException('Mapping type and source value are required.');
            }
            String key = JSON.serialize(new List<String>{
                String.isBlank(input.provider) ? '' : input.provider.trim().toLowerCase(),
                String.isBlank(input.version) ? '' : input.version.trim().toLowerCase()
            });
            if (!scopes.containsKey(key)) {
                scopes.put(key, MappingResolver.loadValues(input.provider, input.version, records));
            }
            Output output = new Output();
            output.value = scopes.get(key).get(input.mappingType)?.get(input.sourceValue);
            output.found = output.value != null;
            outputs.add(output);
        }
        return outputs;
    }
}
