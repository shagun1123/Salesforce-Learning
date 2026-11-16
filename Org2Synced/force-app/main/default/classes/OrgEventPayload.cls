// File: OrgEventPayload.cls
public class OrgEventPayload {
    public String              orgId;
    public String              orgName;
    public String              objectName;
    public String              recordId;
    public String              changeType;       // Created | Updated | Deleted
    public Map<String, Object> recordData;       // generic field map
    public String              timestamp;
}