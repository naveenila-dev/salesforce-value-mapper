/** Machine-readable diagnostic with stable code and affected record identifiers. */
public class ConfigIssue {
    public String code;
    public String severity;
    public String message;
    public List<String> records;

    public ConfigIssue(String code, String severity, String message, List<String> records) {
        this.code = code;
        this.severity = severity;
        this.message = message;
        this.records = records == null ? new List<String>() : records.clone();
    }
}