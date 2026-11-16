// File: OrgSyncCalloutQueueable.cls
public class OrgSyncCalloutQueueable implements Queueable, Database.AllowsCallouts {
    
    private List<OrgEventPayload> payloads;
    
    public OrgSyncCalloutQueueable(List<OrgEventPayload> payloads) {
        this.payloads = payloads;
    }
    
    public static void enqueue(List<OrgEventPayload> payloads) {
        System.enqueueJob(new OrgSyncCalloutQueueable(payloads));
    }
    
    public void execute(QueueableContext ctx) {
        // Named Credential: Org1_Sync (configured in Setup → Named Credentials)
        // It holds the Org 1 instance URL + OAuth token
        String endpoint = 'callout:Org2_Sync/services/apexrest/orgchangeevent';
        String body = JSON.serialize(payloads);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(body);
        req.setTimeout(30000);
        
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            if (res.getStatusCode() != 200) {
                System.debug(LoggingLevel.ERROR, 
                    'OrgSync callout failed: ' + res.getStatusCode() + ' ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OrgSync callout exception: ' + e.getMessage());
        }
    }
}