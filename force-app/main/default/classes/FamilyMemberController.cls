/**
 * Class: FamilyMemberController
 * Purpose: Controller for managing Caregiver Family Members from portal
 * Features:
 * - Add family members to Primary Contact's account
 * - Retrieve family member list
 * - Update family member information
 * - Delete family members
 */
public with sharing class FamilyMemberController {
    
    /**
     * Get all family members for the logged-in user's account
     */
    @AuraEnabled(cacheable=true)
    public static List<FamilyMemberWrapper> getFamilyMembers() {
        try {
            // Get current user's contact
            Id userId = UserInfo.getUserId();
            User currentUser = [
                SELECT ContactId, Contact.AccountId 
                FROM User 
                WHERE Id = :userId 
                LIMIT 1
            ];
            
            if (currentUser.ContactId == null || currentUser.Contact.AccountId == null) {
                throw new AuraHandledException('User is not associated with a Contact or Account');
            }
            
            Id accountId = currentUser.Contact.AccountId;
            Id familyMemberRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
                                         .get('Caregiver_Family_Member').getRecordTypeId();
            
            // Query all family members for this account
            List<Contact> familyMembers = [
                SELECT Id, Name, FirstName, LastName, Email, Phone, MobilePhone,
                       Birthdate, Relationship_to_Primary__c, Background_Check_Status__c,
                       Training_Completed__c, Home_Study_Completed__c
                FROM Contact
                WHERE AccountId = :accountId
                AND RecordTypeId = :familyMemberRecordTypeId
                ORDER BY CreatedDate DESC
            ];
            
            List<FamilyMemberWrapper> wrapperList = new List<FamilyMemberWrapper>();
            
            for (Contact c : familyMembers) {
                FamilyMemberWrapper wrapper = new FamilyMemberWrapper();
                wrapper.id = c.Id;
                wrapper.firstName = c.FirstName;
                wrapper.lastName = c.LastName;
                wrapper.email = c.Email;
                wrapper.phone = c.Phone;
                wrapper.mobilePhone = c.MobilePhone;
                wrapper.birthdate = c.Birthdate;
                wrapper.relationship = c.Relationship_to_Primary__c;
                wrapper.backgroundCheckStatus = c.Background_Check_Status__c;
                wrapper.trainingCompleted = c.Training_Completed__c;
                wrapper.homeStudyCompleted = c.Home_Study_Completed__c;
                
                wrapperList.add(wrapper);
            }
            
            return wrapperList;
            
        } catch (Exception e) {
            // If it's already an AuraHandledException, re-throw it directly
            if (e.getTypeName() == 'System.AuraHandledException') {
                throw e;
            }
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
     * Create a new family member with employment details
     */
    @AuraEnabled
    public static String createFamilyMemberWithDetails(String familyMemberJson, String employmentJson) {
        try {
            // Get current user's account
            Id userId = UserInfo.getUserId();
            User currentUser = [
                SELECT ContactId, Contact.AccountId 
                FROM User 
                WHERE Id = :userId 
                LIMIT 1
            ];
            
            if (currentUser.ContactId == null || currentUser.Contact.AccountId == null) {
                throw new AuraHandledException('User is not associated with a Contact or Account');
            }
            
            Id accountId = currentUser.Contact.AccountId;
            Id familyMemberRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
                                         .get('Caregiver_Family_Member').getRecordTypeId();
            
            // Deserialize the JSON
            FamilyMemberWrapper wrapper = (FamilyMemberWrapper) JSON.deserialize(
                familyMemberJson, 
                FamilyMemberWrapper.class
            );
            
            // Create new Contact record
            Contact newFamilyMember = new Contact(
                FirstName = wrapper.firstName,
                LastName = wrapper.lastName,
                Email = wrapper.email,
                Phone = wrapper.phone,
                MobilePhone = wrapper.mobilePhone,
                Birthdate = wrapper.birthdate,
                Relationship_to_Primary__c = wrapper.relationship,
                Family_Role__c = wrapper.familyRole,
                AccountId = accountId,
                RecordTypeId = familyMemberRecordTypeId,
                Background_Check_Status__c = 'Pending'
            );
            
            insert newFamilyMember;
            
            // Create employment details if provided
            if (String.isNotBlank(employmentJson)) {
                EmploymentHouseholdController.EmploymentWrapper empWrapper = 
                    (EmploymentHouseholdController.EmploymentWrapper) JSON.deserialize(
                        employmentJson, 
                        EmploymentHouseholdController.EmploymentWrapper.class
                    );
                
                if (String.isNotBlank(empWrapper.employerName)) {
                    Employment_Details__c emp = new Employment_Details__c(
                        Contact__c = newFamilyMember.Id,
                        Employer_Name__c = empWrapper.employerName,
                        Job_Title__c = empWrapper.jobTitle,
                        Employment_Status__c = empWrapper.employmentStatus,
                        Start_Date__c = empWrapper.startDate,
                        Monthly_Income__c = empWrapper.monthlyIncome,
                        Is_Current_Employment__c = true
                    );
                    insert emp;
                }
            }
            
            return newFamilyMember.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating family member: ' + e.getMessage());
        }
    }
    
    /**
     * Update an existing family member
     */
    @AuraEnabled
    public static Boolean updateFamilyMember(String familyMemberJson) {
        try {
            FamilyMemberWrapper wrapper = (FamilyMemberWrapper) JSON.deserialize(
                familyMemberJson, 
                FamilyMemberWrapper.class
            );
            
            // Verify the family member belongs to the user's account
            Id userId = UserInfo.getUserId();
            User currentUser = [
                SELECT ContactId, Contact.AccountId 
                FROM User 
                WHERE Id = :userId 
                LIMIT 1
            ];
            
            Contact existingContact = [
                SELECT Id, AccountId 
                FROM Contact 
                WHERE Id = :wrapper.id 
                LIMIT 1
            ];
            
            if (existingContact.AccountId != currentUser.Contact.AccountId) {
                throw new AuraHandledException('Unauthorized access to this record');
            }
            
            // Update the contact
            existingContact.FirstName = wrapper.firstName;
            existingContact.LastName = wrapper.lastName;
            existingContact.Email = wrapper.email;
            existingContact.Phone = wrapper.phone;
            existingContact.MobilePhone = wrapper.mobilePhone;
            existingContact.Birthdate = wrapper.birthdate;
            existingContact.Relationship_to_Primary__c = wrapper.relationship;
            
            update existingContact;
            
            return true;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error updating family member: ' + e.getMessage());
        }
    }
    
    /**
     * Delete a family member
     */
    @AuraEnabled
    public static Boolean deleteFamilyMember(Id familyMemberId) {
        try {
            // Verify the family member belongs to the user's account
            Id userId = UserInfo.getUserId();
            User currentUser = [
                SELECT ContactId, Contact.AccountId 
                FROM User 
                WHERE Id = :userId 
                LIMIT 1
            ];
            
            Contact contactToDelete = [
                SELECT Id, AccountId 
                FROM Contact 
                WHERE Id = :familyMemberId 
                LIMIT 1
            ];
            
            if (contactToDelete.AccountId != currentUser.Contact.AccountId) {
                throw new AuraHandledException('Unauthorized access to this record');
            }
            
            delete contactToDelete;
            
            return true;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting family member: ' + e.getMessage());
        }
    }
    
    /**
     * Get Primary Contact information
     */
    @AuraEnabled(cacheable=true)
    public static PrimaryContactInfo getPrimaryContactInfo() {
        try {
            Id userId = UserInfo.getUserId();
            User currentUser = [
                SELECT ContactId, Contact.Name, Contact.Email, Contact.Phone,
                    Contact.AccountId, Contact.Account.Name
                FROM User 
                WHERE Id = :userId 
                LIMIT 1
            ];
            
            // 1. Check if the user is a Portal/Community user with a Contact
            if (currentUser.ContactId == null) {
                throw new AuraHandledException('This feature is only available for portal users with an associated Contact record.');
            }

            PrimaryContactInfo info = new PrimaryContactInfo();
            info.contactId = currentUser.ContactId;
            
            // 2. Safely access Contact and Account fields
            if (currentUser.Contact != null) {
                info.name = currentUser.Contact.Name;
                info.email = currentUser.Contact.Email;
                info.phone = currentUser.Contact.Phone;
                info.accountId = currentUser.Contact.AccountId;
                
                if (currentUser.Contact.Account != null) {
                    info.accountName = currentUser.Contact.Account.Name;
                }
            }
            
            return info;
            
        } catch (Exception e) {
            // Re-throw AuraHandledException directly, or wrap other errors
            if (e instanceof AuraHandledException) {
                throw e;
            }
            throw new AuraHandledException('Error retrieving primary contact info: ' + e.getMessage());
        }
    }
    /**
     * Create a new family member (simple version for LWC)
     */
    @AuraEnabled
    public static String createFamilyMember(String familyMemberJson) {
        // Calls the detailed method with null for employment details
        return createFamilyMemberWithDetails(familyMemberJson, null);
    }
    /**
     * Wrapper class for Family Member data
     */
    public class FamilyMemberWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String mobilePhone;
        @AuraEnabled public Date birthdate;
        @AuraEnabled public String relationship;
        @AuraEnabled public String familyRole;
        @AuraEnabled public String backgroundCheckStatus;
        @AuraEnabled public Boolean trainingCompleted;
        @AuraEnabled public Boolean homeStudyCompleted;
    }
    
    /**
     * Wrapper class for Primary Contact Info
     */
    public class PrimaryContactInfo {
        @AuraEnabled public String contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
    }
}