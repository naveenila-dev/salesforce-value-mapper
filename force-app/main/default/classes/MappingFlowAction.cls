/** Bulk Flow boundary for provider-scoped value resolution. */
public with sharing class MappingFlowAction {
    public class Input {
        @InvocableVariable(label='Provider' description='Blank selects shared mappings only.')
        public String provider;
        @InvocableVariable(label='Version' description='Blank selects base mappings.')
        public String version;
        @InvocableVariable(label='Mapping Type' required=true)
        public String mappingType;
        @InvocableVariable(label='Source Value' required=true)
        public String sourceValue;
        @InvocableVariable(label='Missing Policy' description='ERROR (default), RETURN_NULL, or USE_DEFAULT.')
        public String missingPolicy;
        @InvocableVariable(label='Default Value' description='Required when Missing Policy is USE_DEFAULT.')
        public String defaultValue;
        @InvocableVariable(label='Strict Version' description='If true, reject unknown versions instead of falling back.')
        public Boolean strictVersion;

        public Input() {}
    }

    public class Output {
        @InvocableVariable(label='Status')
        public String status;
        @InvocableVariable(label='Mapped Value')
        public String value;
        @InvocableVariable(label='Winning Record')
        public String winner;
        @InvocableVariable(label='Winning Layer')
        public String layer;
        @InvocableVariable(label='Fallback Used')
        public Boolean fallbackUsed;
        @InvocableVariable(label='Configuration Digest')
        public String configDigest;
        @InvocableVariable(label='Shadowed Records')
        public List<String> shadowedRecords;
        @InvocableVariable(label='Has Errors' description='True when any diagnostic has ERROR severity.')
        public Boolean hasErrors;
        @InvocableVariable(label='Issue Codes')
        public List<String> issueCodes;
        @InvocableVariable(label='Issue Messages')
        public List<String> issueMessages;
        @InvocableVariable(label='Issues JSON' description='Full diagnostics, including severity and affected records.')
        public String issuesJson;

        public Output() {}
    }

    @InvocableMethod(label='Resolve Value Mappings' description='Translate values using provider and shared configuration. Returns one result per input in the same order.' category='Value Mapper')
    public static List<Output> resolve(List<Input> inputs) {
        return resolve(inputs, null);
    }

    @TestVisible
    private static List<Output> resolve(List<Input> inputs, MappingSnapshot snapshot) {
        List<MappingRequest> requests = new List<MappingRequest>();
        if (inputs != null) {
            for (Input input : inputs) {
                if (input == null) {
                    requests.add(null);
                    continue;
                }
                MappingRequest request = new MappingRequest(
                    input.provider, input.version, input.mappingType, input.sourceValue
                );
                if (!String.isBlank(input.missingPolicy)) { request.missingPolicy = input.missingPolicy; }
                request.defaultValue = input.defaultValue;
                request.strictVersion = input.strictVersion == true;
                requests.add(request);
            }
        }
        // One resolver batch for all Flow interviews; no per-input metadata loads.
        List<MappingResult> results = snapshot == null
            ? MappingResolver.resolveAll(requests)
            : MappingResolver.resolveAll(requests, snapshot);
        List<Output> outputs = new List<Output>();
        for (MappingResult result : results) {
            Output output = new Output();
            output.status = result.status;
            output.value = result.value;
            output.winner = result.winner;
            output.layer = result.layer;
            output.fallbackUsed = result.fallbackUsed;
            output.configDigest = result.configDigest;
            output.shadowedRecords = result.shadowedRecords;
            output.hasErrors = false;
            output.issueCodes = new List<String>();
            output.issueMessages = new List<String>();
            for (ConfigIssue issue : result.issues) {
                output.issueCodes.add(issue.code);
                output.issueMessages.add(issue.message);
                if (issue.severity == 'ERROR') { output.hasErrors = true; }
            }
            output.issuesJson = JSON.serialize(result.issues);
            outputs.add(output);
        }
        return outputs;
    }
}
