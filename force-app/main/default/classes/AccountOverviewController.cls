/**
 * Class: AccountOverviewController
 * Purpose: Provide comprehensive account overview for administrators
 */
public with sharing class AccountOverviewController {
    
    /**
     * Get complete account overview including all contacts, household, and caseworker info
     */
    @AuraEnabled(cacheable=true)
    public static AccountOverviewWrapper getAccountOverview(Id accountId) {
        try {
            AccountOverviewWrapper overview = new AccountOverviewWrapper();
            
            // Get Account details
            Account acc = [
                SELECT Id, Name, Phone, BillingStreet, BillingCity, BillingState,
                       BillingPostalCode, BillingCountry, Primary_Caseworker__c,
                       Primary_Caseworker__r.Name, Primary_Caseworker__r.Email,
                       Primary_Caseworker__r.Phone
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            
            overview.accountId = acc.Id;
            overview.accountName = acc.Name;
            overview.accountPhone = acc.Phone;
            overview.accountAddress = (acc.BillingStreet != null ? acc.BillingStreet + ', ' : '') +
                                     (acc.BillingCity != null ? acc.BillingCity + ', ' : '') +
                                     (acc.BillingState != null ? acc.BillingState + ' ' : '') +
                                     (acc.BillingPostalCode != null ? acc.BillingPostalCode : '');
            
            if (acc.Primary_Caseworker__c != null) {
                overview.primaryCaseworkerName = acc.Primary_Caseworker__r.Name;
                overview.primaryCaseworkerEmail = acc.Primary_Caseworker__r.Email;
                overview.primaryCaseworkerPhone = acc.Primary_Caseworker__r.Phone;
            }
            
            // Get all contacts related to account
            overview.contacts = getAccountContacts(accountId);
            
            // Get household background
            overview.householdInfo = EmploymentHouseholdController.getHouseholdBackground(accountId);
            
            // Calculate statistics
            overview.totalFamilyMembers = overview.contacts.size();
            overview.primaryContacts = 0;
            overview.caregiverMembers = 0;
            
            for (ContactInfo contact : overview.contacts) {
                if (contact.recordType == 'Primary Contact') {
                    overview.primaryContacts++;
                } else if (contact.recordType == 'Caregiver Family Member') {
                    overview.caregiverMembers++;
                }
            }
            
            return overview;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving account overview: ' + e.getMessage());
        }
    }
    
    /**
     * Get all contacts for an account with their details
     */
    private static List<ContactInfo> getAccountContacts(Id accountId) {
        List<ContactInfo> contactList = new List<ContactInfo>();
        
        // Get Primary Contact and Caregiver Family Member record type IDs
        Id primaryRTId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
                        .get('Primary_Contact').getRecordTypeId();
        Id caregiverRTId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
                          .get('Caregiver_Family_Member').getRecordTypeId();
        
        List<Contact> contacts = [
            SELECT Id, Name, FirstName, LastName, Email, Phone, MobilePhone,
                   Birthdate, RecordTypeId, RecordType.Name, Relationship_to_Primary__c,
                   Family_Role__c, Background_Check_Status__c, Training_Completed__c,
                   Home_Study_Completed__c,
                   (SELECT Id, Employer_Name__c, Job_Title__c, Employment_Status__c,
                           Monthly_Income__c, Is_Current_Employment__c
                    FROM Employment_Details__r
                    WHERE Is_Current_Employment__c = true
                    LIMIT 1)
            FROM Contact
            WHERE AccountId = :accountId
            AND RecordTypeId IN (:primaryRTId, :caregiverRTId)
            ORDER BY RecordTypeId, CreatedDate
        ];
        
        for (Contact con : contacts) {
            ContactInfo info = new ContactInfo();
            info.contactId = con.Id;
            info.name = con.Name;
            info.firstName = con.FirstName;
            info.lastName = con.LastName;
            info.email = con.Email;
            info.phone = con.Phone;
            info.mobilePhone = con.MobilePhone;
            info.birthdate = con.Birthdate;
            info.recordType = con.RecordType.Name;
            info.relationshipToPrimary = con.Relationship_to_Primary__c;
            info.familyRole = con.Family_Role__c;
            info.backgroundCheckStatus = con.Background_Check_Status__c;
            info.trainingCompleted = con.Training_Completed__c;
            info.homeStudyCompleted = con.Home_Study_Completed__c;
            
            // Get current employment
            if (!con.Employment_Details__r.isEmpty()) {
                Employment_Details__c emp = con.Employment_Details__r[0];
                info.currentEmployer = emp.Employer_Name__c;
                info.currentJobTitle = emp.Job_Title__c;
                info.employmentStatus = emp.Employment_Status__c;
                info.monthlyIncome = emp.Monthly_Income__c;
            }
            
            contactList.add(info);
        }
        
        return contactList;
    }
    
    /**
     * Get contact details with employment history
     */
    @AuraEnabled(cacheable=true)
    public static ContactDetailWrapper getContactDetails(Id contactId) {
        try {
            Contact con = [
                SELECT Id, Name, FirstName, LastName, Email, Phone, MobilePhone,
                       Birthdate, RecordType.Name, Relationship_to_Primary__c,
                       Family_Role__c, Background_Check_Status__c, Training_Completed__c,
                       Home_Study_Completed__c, AccountId
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];
            
            ContactDetailWrapper detail = new ContactDetailWrapper();
            detail.contactId = con.Id;
            detail.name = con.Name;
            detail.email = con.Email;
            detail.phone = con.Phone;
            detail.recordType = con.RecordType.Name;
            detail.familyRole = con.Family_Role__c;
            detail.backgroundCheckStatus = con.Background_Check_Status__c;
            
            // Get employment history
            detail.employmentHistory = EmploymentHouseholdController.getEmploymentDetails(contactId);
            
            return detail;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving contact details: ' + e.getMessage());
        }
    }
    
    /**
     * Wrapper classes
     */
    public class AccountOverviewWrapper {
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String accountPhone;
        @AuraEnabled public String accountAddress;
        @AuraEnabled public String primaryCaseworkerName;
        @AuraEnabled public String primaryCaseworkerEmail;
        @AuraEnabled public String primaryCaseworkerPhone;
        @AuraEnabled public List<ContactInfo> contacts;
        @AuraEnabled public EmploymentHouseholdController.HouseholdWrapper householdInfo;
        @AuraEnabled public Integer totalFamilyMembers;
        @AuraEnabled public Integer primaryContacts;
        @AuraEnabled public Integer caregiverMembers;
    }
    
    public class ContactInfo {
        @AuraEnabled public String contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String mobilePhone;
        @AuraEnabled public Date birthdate;
        @AuraEnabled public String recordType;
        @AuraEnabled public String relationshipToPrimary;
        @AuraEnabled public String familyRole;
        @AuraEnabled public String backgroundCheckStatus;
        @AuraEnabled public Boolean trainingCompleted;
        @AuraEnabled public Boolean homeStudyCompleted;
        @AuraEnabled public String currentEmployer;
        @AuraEnabled public String currentJobTitle;
        @AuraEnabled public String employmentStatus;
        @AuraEnabled public Decimal monthlyIncome;
    }
    
    public class ContactDetailWrapper {
        @AuraEnabled public String contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String recordType;
        @AuraEnabled public String familyRole;
        @AuraEnabled public String backgroundCheckStatus;
        @AuraEnabled public List<EmploymentHouseholdController.EmploymentWrapper> employmentHistory;
    }
}