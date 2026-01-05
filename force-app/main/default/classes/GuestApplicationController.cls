/**
 * Class: GuestApplicationController
 * Purpose: Handle guest/public application submissions with family members
 * This runs WITHOUT SHARING to allow guest users to create records
 */
public without sharing class GuestApplicationController {
    
    /**
     * Submit complete application with family members and household info
     * This method is called by guest users from the public form
     */
    @AuraEnabled
    public static String submitApplication(String applicationDataJson) {
        try {
            // Parse the JSON
            ApplicationData data = (ApplicationData) JSON.deserialize(
                applicationDataJson, 
                ApplicationData.class
            );
            
            // Create the Lead (Primary Applicant)
            Lead newLead = new Lead(
                FirstName = data.primaryApplicant.firstName,
                LastName = data.primaryApplicant.lastName,
                Email = data.primaryApplicant.email,
                Phone = data.primaryApplicant.phone,
                Company = String.isNotBlank(data.primaryApplicant.company) ? 
                         data.primaryApplicant.company : 
                         data.primaryApplicant.firstName + ' ' + data.primaryApplicant.lastName + ' Family',
                Street = data.primaryApplicant.street,
                City = data.primaryApplicant.city,
                State = data.primaryApplicant.state,
                PostalCode = data.primaryApplicant.postalCode,
                Application_Type__c = data.primaryApplicant.applicationType,
                Application_Status__c = 'New',
                Status = 'Open - Not Contacted',
                LeadSource = 'Web'
            );
            
            insert newLead;
            
            // Store family members and household info as JSON in Lead description/notes
            // This will be processed when Lead is converted
            Map<String, Object> additionalInfo = new Map<String, Object>();
            additionalInfo.put('familyMembers', data.familyMembers);
            additionalInfo.put('householdInfo', data.householdInfo);
            
            newLead.Description = JSON.serialize(additionalInfo);
            update newLead;
            
            return newLead.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error submitting application: ' + e.getMessage());
        }
    }
    
    /**
     * Wrapper classes for JSON deserialization
     */
    public class ApplicationData {
        public PrimaryApplicantData primaryApplicant;
        public List<FamilyMemberData> familyMembers;
        public HouseholdInfoData householdInfo;
    }
    
    public class PrimaryApplicantData {
        public String firstName;
        public String lastName;
        public String email;
        public String phone;
        public String company;
        public String street;
        public String city;
        public String state;
        public String postalCode;
        public String applicationType;
    }
    
    public class FamilyMemberData {
        public String firstName;
        public String lastName;
        public String email;
        public String phone;
        public Date birthdate;
        public String relationship;
        public String employerName;
        public String jobTitle;
        public Decimal monthlyIncome;
    }
    
    public class HouseholdInfoData {
        public String homeType;
        public Integer bedrooms;
        public Integer squareFootage;
        public Boolean hasPool;
        public Boolean hasPets;
        public String petDetails;
        public Boolean smoking;
    }
}