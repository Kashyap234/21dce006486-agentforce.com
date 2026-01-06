/**
 * Class: CaseworkerAssignmentService
 * Purpose: Manage automatic assignment of caseworkers using round-robin logic
 * Features:
 * - Assigns caseworker with lowest case load
 * - Checks availability status
 * - Respects maximum case load limits
 * - Automatically updates case load counts
 */
public class CaseworkerAssignmentService {
    
    /**
     * Assign an available caseworker based on current workload
     * Returns: Contact Id of assigned caseworker or null if none available
     */
    public static Id assignAvailableCaseworker() {
        try {
            Id caseworkerRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
                                       .get('Caseworker').getRecordTypeId();
            
            // Query available caseworkers ordered by current case load (lowest first)
            List<Contact> availableCaseworkers = [
                SELECT Id, Name, Current_Case_Load__c, Maximum_Case_Load__c,
                       Email, Phone
                FROM Contact
                WHERE RecordTypeId = :caseworkerRecordTypeId
                AND Availability_Status__c = 'Available'
                ORDER BY Current_Case_Load__c ASC NULLS FIRST, LastModifiedDate ASC
                LIMIT 1
            ];
            
            if (!availableCaseworkers.isEmpty()) {
                Contact assignedCaseworker = availableCaseworkers[0];
                
                // Check if caseworker is at maximum capacity
                Decimal currentLoad = assignedCaseworker.Current_Case_Load__c != null ? 
                                     assignedCaseworker.Current_Case_Load__c : 0;
                Decimal maxLoad = assignedCaseworker.Maximum_Case_Load__c != null ? 
                                 assignedCaseworker.Maximum_Case_Load__c : 10;
                
                if (currentLoad >= maxLoad) {
                    System.debug('No available caseworkers - all at maximum capacity');
                    return null;
                }
                
                // Increment case load
                assignedCaseworker.Current_Case_Load__c = currentLoad + 1;
                
                // Update availability status if reaching maximum capacity
                if (assignedCaseworker.Current_Case_Load__c >= assignedCaseworker.Maximum_Case_Load__c) {
                    assignedCaseworker.Availability_Status__c = 'Busy';
                }
                
                update assignedCaseworker;
                
                System.debug('Assigned Caseworker: ' + assignedCaseworker.Name + 
                           ' (Current Load: ' + assignedCaseworker.Current_Case_Load__c + ')');
                
                return assignedCaseworker.Id;
            } else {
                System.debug('No available caseworkers found');
                return null;
            }
            
        } catch (Exception e) {
            System.debug('Error in assignAvailableCaseworker: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Release a caseworker (decrease case load)
     * Called when a case is closed or reassigned
     */
    public static void releaseCaseworker(Id caseworkerId) {
        try {
            Contact caseworker = [
                SELECT Id, Current_Case_Load__c, Maximum_Case_Load__c, 
                       Availability_Status__c
                FROM Contact 
                WHERE Id = :caseworkerId 
                LIMIT 1
            ];
            
            if (caseworker.Current_Case_Load__c != null && caseworker.Current_Case_Load__c > 0) {
                caseworker.Current_Case_Load__c -= 1;
                
                // Update availability status back to Available if under maximum
                if (caseworker.Current_Case_Load__c < caseworker.Maximum_Case_Load__c) {
                    caseworker.Availability_Status__c = 'Available';
                }
                
                update caseworker;
                System.debug('Released Caseworker: ' + caseworker.Id);
            }
            
        } catch (Exception e) {
            System.debug('Error in releaseCaseworker: ' + e.getMessage());
        }
    }
    
    /**
     * Reassign caseworker from one to another
     * Used when manual reassignment is needed
     */
    public static Boolean reassignCaseworker(Id oldCaseworkerId, Id newCaseworkerId) {
        try {
            if (oldCaseworkerId != null) {
                releaseCaseworker(oldCaseworkerId);
            }
            
            if (newCaseworkerId != null) {
                Contact newCaseworker = [
                    SELECT Id, Current_Case_Load__c, Maximum_Case_Load__c
                    FROM Contact
                    WHERE Id = :newCaseworkerId
                    LIMIT 1
                ];
                
                newCaseworker.Current_Case_Load__c = 
                    (newCaseworker.Current_Case_Load__c != null ? 
                     newCaseworker.Current_Case_Load__c : 0) + 1;
                
                if (newCaseworker.Current_Case_Load__c >= newCaseworker.Maximum_Case_Load__c) {
                    newCaseworker.Availability_Status__c = 'Busy';
                }
                
                update newCaseworker;
            }
            
            return true;
            
        } catch (Exception e) {
            System.debug('Error in reassignCaseworker: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * Get list of available caseworkers with their current workload
     * Used for manual assignment UI
     * REMOVED cacheable=true to allow imperative calls
     */
    @AuraEnabled
    public static List<CaseworkerInfo> getAvailableCaseworkers() {
        try {
            Id caseworkerRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
                                       .get('Caseworker').getRecordTypeId();
            
            List<Contact> caseworkers = [
                SELECT Id, Name, Email, Phone, Current_Case_Load__c, 
                       Maximum_Case_Load__c, Availability_Status__c, Specialization__c
                FROM Contact
                WHERE RecordTypeId = :caseworkerRecordTypeId
                AND Availability_Status__c IN ('Available', 'Busy')
                ORDER BY Current_Case_Load__c ASC NULLS FIRST
            ];
            
            List<CaseworkerInfo> caseworkerList = new List<CaseworkerInfo>();
            
            for (Contact cw : caseworkers) {
                CaseworkerInfo info = new CaseworkerInfo();
                info.id = cw.Id;
                info.name = cw.Name;
                info.email = cw.Email;
                info.phone = cw.Phone;
                info.currentCaseLoad = cw.Current_Case_Load__c != null ? 
                                       Integer.valueOf(cw.Current_Case_Load__c) : 0;
                info.maximumCaseLoad = cw.Maximum_Case_Load__c != null ? 
                                       Integer.valueOf(cw.Maximum_Case_Load__c) : 10;
                info.availabilityStatus = cw.Availability_Status__c;
                info.specialization = cw.Specialization__c;
                
                caseworkerList.add(info);
            }
            
            return caseworkerList;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving caseworkers: ' + e.getMessage());
        }
    }
    
    /**
     * Wrapper class for caseworker information
     */
    public class CaseworkerInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public Integer currentCaseLoad;
        @AuraEnabled public Integer maximumCaseLoad;
        @AuraEnabled public String availabilityStatus;
        @AuraEnabled public String specialization;
    }
}