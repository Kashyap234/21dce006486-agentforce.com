/**
 * Class: LeadConversionHandler
 * Purpose: Handle automatic Lead conversion when status changes to "Eligible for Foster"
 * Features: 
 * - Converts Lead to Account and Contact (Foster Parents)
 * - Converts Lead to Contact only (Caseworkers)
 * - Sets appropriate Contact Record Type based on Application Type
 * - Assigns Caseworker automatically if Application Type is for foster family
 */
public class LeadConversionHandler {
    
    /**
     * Main handler method called from trigger
     */
    public static void handleLeadConversion(List<Lead> newLeads, Map<Id, Lead> oldLeadMap) {
        List<Id> leadsToConvert = new List<Id>();
        List<Id> caseworkerLeads = new List<Id>();
        
        for (Lead lead : newLeads) {
            Lead oldLead = oldLeadMap.get(lead.Id);
            
            // Check if status changed to "Eligible for Foster" and Lead is not already converted
            if (lead.Application_Status__c == 'Eligible for Foster' && 
                oldLead.Application_Status__c != 'Eligible for Foster' &&
                !lead.IsConverted) {
                
                if (lead.Application_Type__c == 'Caseworker') {
                    caseworkerLeads.add(lead.Id);
                } else {
                    leadsToConvert.add(lead.Id);
                }
            }
        }
        
        // Call future methods for conversion
        if (!leadsToConvert.isEmpty()) {
            convertLeadsToAccountContactFuture(leadsToConvert);
        }
        
        if (!caseworkerLeads.isEmpty()) {
            convertCaseworkerLeadsFuture(caseworkerLeads);
        }
    }
    
    /**
     * Future method to handle Caseworker Lead conversion (Contact only, no Account)
     */
    @future
    public static void convertCaseworkerLeadsFuture(List<Id> leadIds) {
        List<Lead> leads = [
            SELECT Id, FirstName, LastName, Company, Email, Phone, 
                   MobilePhone, Street, City, State, PostalCode, Country,
                   Application_Type__c, Background_Check_Status__c, Description
            FROM Lead 
            WHERE Id IN :leadIds AND IsConverted = false
        ];
        
        for (Lead lead : leads) {
            try {
                // Get Caseworker Record Type
                Id caseworkerRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
                                          .get('Caseworker').getRecordTypeId();
                
                // Create Contact directly without Account
                Contact caseworkerContact = new Contact(
                    FirstName = lead.FirstName,
                    LastName = lead.LastName,
                    Email = lead.Email,
                    Phone = lead.Phone,
                    MobilePhone = lead.MobilePhone,
                    RecordTypeId = caseworkerRecordTypeId,
                    Availability_Status__c = 'Available',
                    Current_Case_Load__c = 0,
                    Maximum_Case_Load__c = 10
                    // Note: No Family_Role__c field set for Caseworkers
                );
                
                insert caseworkerContact;
                
                // Mark Lead as converted manually
                lead.Status = 'Closed - Converted';
                lead.IsConverted = true;
                update lead;
                
                System.debug('Successfully created Caseworker Contact: ' + caseworkerContact.Id);
                
            } catch (Exception e) {
                System.debug('Error creating Caseworker Contact: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Future method to handle Lead conversion asynchronously (Foster Parents)
     */
    @future
    public static void convertLeadsToAccountContactFuture(List<Id> leadIds) {
        // Query leads with all necessary fields
        List<Lead> leads = [
            SELECT Id, FirstName, LastName, Company, Email, Phone, 
                   MobilePhone, Street, City, State, PostalCode, Country,
                   Application_Type__c, Background_Check_Status__c, Description
            FROM Lead 
            WHERE Id IN :leadIds AND IsConverted = false
        ];
        
        List<Database.LeadConvertResult> results = new List<Database.LeadConvertResult>();
        
        for (Lead lead : leads) {
            try {
                // Create LeadConvert object
                Database.LeadConvert lc = new Database.LeadConvert();
                lc.setLeadId(lead.Id);
                
                // Don't create Opportunity
                lc.setDoNotCreateOpportunity(true);
                
                // Get converted status
                LeadStatus convertStatus = [
                    SELECT Id, MasterLabel 
                    FROM LeadStatus 
                    WHERE IsConverted = true 
                    LIMIT 1
                ];
                lc.setConvertedStatus(convertStatus.MasterLabel);
                
                // Convert the lead
                Database.LeadConvertResult lcr = Database.convertLead(lc);
                results.add(lcr);
                
                if (lcr.isSuccess()) {
                    System.debug('Successfully converted Lead: ' + lead.Id);
                    
                    // Update Contact with correct Record Type and assign caseworker if needed
                    updateContactAfterConversion(
                        lcr.getContactId(), 
                        lcr.getAccountId(),
                        lead.Application_Type__c,
                        lead.Description
                    );
                } else {
                    for (Database.Error error : lcr.getErrors()) {
                        System.debug('Error converting Lead: ' + error.getMessage());
                    }
                }
            } catch (Exception e) {
                System.debug('Exception in Lead conversion: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Update Contact record type and assign caseworker after conversion
     */
    private static void updateContactAfterConversion(Id contactId, Id accountId, String applicationType, String leadDescription) {
        try {
            // Get Primary Contact Record Type
            Id recordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
                            .get('Primary_Contact').getRecordTypeId();
            
            Contact con = new Contact(
                Id = contactId,
                RecordTypeId = recordTypeId,
                Family_Role__c = 'Primary Foster Parent'
            );
            
            // Assign a caseworker to the account
            Id assignedCaseworkerId = CaseworkerAssignmentService.assignAvailableCaseworker();
            
            if (assignedCaseworkerId != null) {
                // Create relationship between Account and Caseworker
                Account acc = new Account(
                    Id = accountId,
                    Primary_Caseworker__c = assignedCaseworkerId
                );
                update acc;
            }
            
            update con;
            System.debug('Successfully updated Contact Record Type');
            
            // Process family members and household info from Lead Description
            if (String.isNotBlank(leadDescription)) {
                processFamilyAndHouseholdData(accountId, leadDescription);
            }
            
            // Create portal user for Foster Parent
            createPortalUser(contactId);
            
        } catch (Exception e) {
            System.debug('Error updating Contact: ' + e.getMessage());
        }
    }
    
    /**
     * Process family members and household info stored in Lead Description
     */
    private static void processFamilyAndHouseholdData(Id accountId, String leadDescription) {
        try {
            Map<String, Object> additionalInfo = (Map<String, Object>) JSON.deserializeUntyped(leadDescription);
            
            // Create family member contacts
            if (additionalInfo.containsKey('familyMembers')) {
                List<Object> familyMembersList = (List<Object>) additionalInfo.get('familyMembers');
                createFamilyMemberContacts(accountId, familyMembersList);
            }
            
            // Create household background
            if (additionalInfo.containsKey('householdInfo')) {
                Map<String, Object> householdData = (Map<String, Object>) additionalInfo.get('householdInfo');
                createHouseholdBackground(accountId, householdData);
            }
            
        } catch (Exception e) {
            System.debug('Error processing family and household data: ' + e.getMessage());
        }
    }
    
    /**
     * Create family member contacts
     */
    private static void createFamilyMemberContacts(Id accountId, List<Object> familyMembersList) {
        try {
            Id familyMemberRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
                                         .get('Caregiver_Family_Member').getRecordTypeId();
            
            List<Contact> familyContacts = new List<Contact>();
            List<Map<String, Object>> employmentDataList = new List<Map<String, Object>>();
            
            for (Object memberObj : familyMembersList) {
                Map<String, Object> member = (Map<String, Object>) memberObj;
                
                Contact famContact = new Contact(
                    FirstName = (String) member.get('firstName'),
                    LastName = (String) member.get('lastName'),
                    Email = (String) member.get('email'),
                    Phone = (String) member.get('phone'),
                    Birthdate = member.get('birthdate') != null ? Date.valueOf((String) member.get('birthdate')) : null,
                    Relationship_to_Primary__c = (String) member.get('relationship'),
                    AccountId = accountId,
                    RecordTypeId = familyMemberRecordTypeId,
                    Background_Check_Status__c = 'Pending'
                );
                
                familyContacts.add(famContact);
                
                // Store employment data for later
                if (String.isNotBlank((String) member.get('employerName'))) {
                    employmentDataList.add(member);
                }
            }
            
            if (!familyContacts.isEmpty()) {
                insert familyContacts;
                
                // Create employment records
                if (!employmentDataList.isEmpty()) {
                    createEmploymentRecords(familyContacts, employmentDataList);
                }
            }
            
        } catch (Exception e) {
            System.debug('Error creating family member contacts: ' + e.getMessage());
        }
    }
    
    /**
     * Create employment records for family members
     */
    private static void createEmploymentRecords(List<Contact> contacts, List<Map<String, Object>> employmentDataList) {
        try {
            List<Employment_Details__c> empRecords = new List<Employment_Details__c>();
            
            for (Integer i = 0; i < Math.min(contacts.size(), employmentDataList.size()); i++) {
                Map<String, Object> empData = employmentDataList[i];
                
                Employment_Details__c emp = new Employment_Details__c(
                    Contact__c = contacts[i].Id,
                    Employer_Name__c = (String) empData.get('employerName'),
                    Job_Title__c = (String) empData.get('jobTitle'),
                    Monthly_Income__c = (Decimal) empData.get('monthlyIncome'),
                    Is_Current_Employment__c = true,
                    Employment_Status__c = 'Full Time'
                );
                
                empRecords.add(emp);
            }
            
            if (!empRecords.isEmpty()) {
                insert empRecords;
            }
            
        } catch (Exception e) {
            System.debug('Error creating employment records: ' + e.getMessage());
        }
    }
    
    /**
     * Create household background record
     */
    private static void createHouseholdBackground(Id accountId, Map<String, Object> householdData) {
        try {
            Household_Background__c hh = new Household_Background__c(
                Family_Account__c = accountId,
                Home_Type__c = (String) householdData.get('homeType'),
                Number_of_Bedrooms__c = (Integer) householdData.get('bedrooms'),
                Square_Footage__c = (Integer) householdData.get('squareFootage'),
                Has_Pool__c = (Boolean) householdData.get('hasPool'),
                Has_Pets__c = (Boolean) householdData.get('hasPets'),
                Pet_Details__c = (String) householdData.get('petDetails'),
                Smoking_Household__c = (Boolean) householdData.get('smoking')
            );
            
            insert hh;
            
        } catch (Exception e) {
            System.debug('Error creating household background: ' + e.getMessage());
        }
    }
    
    /**
     * Create Experience Cloud portal user for the contact
     */
    private static void createPortalUser(Id contactId) {
        try {
            Contact con = [SELECT Id, Email, FirstName, LastName, AccountId 
                          FROM Contact 
                          WHERE Id = :contactId LIMIT 1];
            
            if (con.Email == null) {
                System.debug('Cannot create user - Contact has no email');
                return;
            }
            
            // Get the portal profile
            Profile portalProfile = [SELECT Id FROM Profile 
                                    WHERE Name = 'Customer Community Plus User' 
                                    LIMIT 1];
            
            // Create username from email
            String username = con.Email + '.fostercare';
            
            // Check if user already exists
            List<User> existingUsers = [SELECT Id FROM User WHERE Username = :username];
            if (!existingUsers.isEmpty()) {
                System.debug('User already exists with this username');
                return;
            }
            
            // Create user
            User portalUser = new User(
                Username = username,
                Email = con.Email,
                FirstName = con.FirstName,
                LastName = con.LastName,
                Alias = con.FirstName.substring(0, Math.min(con.FirstName.length(), 4)) + 
                        con.LastName.substring(0, Math.min(con.LastName.length(), 4)),
                ContactId = con.Id,
                ProfileId = portalProfile.Id,
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey = 'America/Los_Angeles',
                IsActive = true
            );
            
            insert portalUser;
            System.debug('Successfully created portal user: ' + username);
            
            // Send welcome email
            sendWelcomeEmail(con.Email, con.FirstName);
            
        } catch (Exception e) {
            System.debug('Error creating portal user: ' + e.getMessage());
        }
    }
    
    /**
     * Send welcome email to new portal user
     */
    private static void sendWelcomeEmail(String toEmail, String firstName) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { toEmail });
            mail.setSubject('Welcome to Foster Care Portal - Application Approved');
            
            String emailBody = 'Dear ' + firstName + ',\n\n' +
                             'Congratulations! Your foster care application has been approved.\n\n' +
                             'You can now access the Foster Care Portal to:\n' +
                             '- View your application status\n' +
                             '- Add family member details\n' +
                             '- Complete required documentation\n' +
                             '- Track your progress\n\n' +
                             'Login URL: [Your Portal URL]\n' +
                             'Username: ' + toEmail + '.fostercare\n\n' +
                             'You will receive a separate email to set your password.\n\n' +
                             'Best regards,\n' +
                             'Foster Care Team';
            
            mail.setPlainTextBody(emailBody);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
        }
    }
}