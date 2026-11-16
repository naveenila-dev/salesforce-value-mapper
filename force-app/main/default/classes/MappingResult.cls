/** Resolution outcome and provenance. No original-value passthrough is performed. */
public class MappingResult {
    public String status;
    public String value;
    public String winner;
    public String layer;
    public Boolean fallbackUsed = false;
    public String configDigest;
    public List<String> shadowedRecords = new List<String>();
    public List<ConfigIssue> issues = new List<ConfigIssue>();
}
