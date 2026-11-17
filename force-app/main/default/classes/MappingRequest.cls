/** Exact input strings; provider/version scopes are normalized by the resolver. */
public class MappingRequest {
    public String provider;
    public String version;
    public String mappingType;
    public String sourceValue;
    public String missingPolicy = 'ERROR';
    public String defaultValue;
    public Boolean strictVersion = false;

    public MappingRequest() {}
    public MappingRequest(String provider, String version, String mappingType, String sourceValue) {
        this.provider = provider;
        this.version = version;
        this.mappingType = mappingType;
        this.sourceValue = sourceValue;
    }
}