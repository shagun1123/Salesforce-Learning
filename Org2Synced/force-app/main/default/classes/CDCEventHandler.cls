// // File: CDCEventHandler.cls
// public class CDCEventHandler {

//     // Central config: which fields to extract per object
//     // In production, drive this from Custom Metadata instead
//     private static final Map<String, List<String>> TRACKED_FIELDS = new Map<String, List<String>>{
//         'Contact' => new List<String>{ 'FirstName', 'LastName', 'Email', 'Phone' },
//         'Account' => new List<String>{ 'Name', 'Phone', 'Website', 'BillingCity' },
//         'Lead'    => new List<String>{ 'FirstName', 'LastName', 'Email', 'Company' }
//     };

//     // ── Main entry point called by every CDC trigger ─────────────────────────
//     public static void handle(List<SObject> changeEvents, String objectApiName) {
//         List<OrgEventPayload> payloads = new List<OrgEventPayload>();

//         for (SObject event : changeEvents) {
//             EventBus.ChangeEventHeader header = 
//                 (EventBus.ChangeEventHeader) event.get('ChangeEventHeader');

//             String rawChangeType = header.changeType;
//             if (!new Set<String>{ 'CREATE', 'UPDATE', 'DELETE' }.contains(rawChangeType)) {
//                 continue; // skip GAP_CREATE, GAP_UPDATE, UNDELETE etc.
//             }

//             String changeType = rawChangeType == 'CREATE' ? 'Created'
//                               : rawChangeType == 'DELETE' ? 'Deleted'
//                               : 'Updated';

//             // Extract configured fields generically
//             Map<String, Object> fieldValues = extractFields(event, objectApiName);

//             for (String recordId : header.recordIds) {
//                 OrgEventPayload p   = new OrgEventPayload();
//                 p.orgId             = UserInfo.getOrganizationId();
//                 p.orgName           = UserInfo.getOrganizationName();
//                 p.objectName        = objectApiName;
//                 p.recordId          = recordId;
//                 p.changeType        = changeType;
//                 p.recordData        = fieldValues;
//                 p.timestamp         = String.valueOf(System.now());
//                 payloads.add(p);
//             }
//         }

//         if (!payloads.isEmpty()) {
//             OrgSyncCalloutQueueable.enqueue(payloads);
//         }
//     }

//     // ── Extract fields from the CDC event SObject generically ────────────────
//     private static Map<String, Object> extractFields(SObject event, String objectApiName) {
//         Map<String, Object> result = new Map<String, Object>();
//         List<String> fields = TRACKED_FIELDS.get(objectApiName);

//         if (fields == null) return result; // no config, return empty

//         Map<String, Object> allFields = event.getPopulatedFieldsAsMap();

//         for (String fieldName : fields) {
//             // CDC only populates changed fields — null means unchanged, not blank
//             if (allFields.containsKey(fieldName)) {
//                 result.put(fieldName, allFields.get(fieldName));
//             }
//         }
//         return result;
//     }
// }
public class CDCEventHandler {

    private static List<String> getTrackableFields(String objectApiName) {
        Map<String, Schema.SObjectField> fieldMap =
            Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();

        List<String> fieldNames = new List<String>();

        for (String apiName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fd = fieldMap.get(apiName).getDescribe();

            if ((fd.isCreateable() || fd.isUpdateable())
                && !fd.isCalculated()
                && fd.getType() != Schema.DisplayType.Address
                && fd.getType() != Schema.DisplayType.Location
                && fd.getType() != Schema.DisplayType.Base64) {
                fieldNames.add(apiName);
            }
        }

        return fieldNames;
    }

    public static void handle(List<SObject> changeEvents, String objectApiName) {
        List<OrgEventPayload> payloads = new List<OrgEventPayload>();

        Set<Id> snapshotIds = new Set<Id>();
        Map<String, Map<String, Object>> recordData = new Map<String, Map<String, Object>>();
        Map<String, String> recordChangeTypes = new Map<String, String>();

        for (SObject event : changeEvents) {
            EventBus.ChangeEventHeader header =
                (EventBus.ChangeEventHeader) event.get('ChangeEventHeader');

            String rawChangeType = header.changeType;
            if (!new Set<String>{ 'CREATE', 'UPDATE', 'DELETE' }.contains(rawChangeType)) {
                continue;
            }

            String changeType = rawChangeType == 'CREATE' ? 'Created'
                              : rawChangeType == 'DELETE' ? 'Deleted'
                              : 'Updated';

            for (String recordId : header.recordIds) {
                recordChangeTypes.put(recordId, changeType);

                if (changeType == 'Deleted') {
                    recordData.put(recordId, new Map<String, Object>());
                } else {
                    snapshotIds.add((Id) recordId);
                }
            }
        }

        if (!snapshotIds.isEmpty()) {
            List<String> fieldNames = getTrackableFields(objectApiName);

            String query = 'SELECT Id, ' + String.join(fieldNames, ', ')
                         + ' FROM ' + objectApiName
                         + ' WHERE Id IN :snapshotIds';

            for (SObject record : Database.query(query)) {
                Map<String, Object> fields = new Map<String, Object>();
                for (String f : fieldNames) {
                    Object val = record.get(f);
                    if (val != null) {
                        fields.put(f, val);
                    }
                }
                recordData.put((String) record.get('Id'), fields);
            }
        }

        for (String recordId : recordChangeTypes.keySet()) {
            OrgEventPayload p = new OrgEventPayload();
            p.orgId      = UserInfo.getOrganizationId();
            p.orgName    = UserInfo.getOrganizationName();
            p.objectName = objectApiName;
            p.recordId   = recordId;
            p.changeType = recordChangeTypes.get(recordId);
            p.recordData = recordData.containsKey(recordId)
                ? recordData.get(recordId)
                : new Map<String, Object>();
            p.timestamp  = String.valueOf(System.now());
            payloads.add(p);
        }

        if (!payloads.isEmpty()) {
            OrgSyncCalloutQueueable.enqueue(payloads);
        }
    }
}
