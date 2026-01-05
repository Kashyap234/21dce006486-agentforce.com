/**
 * Class: EmploymentHouseholdController
 * Purpose: Manage Employment and Household Background records
 */
public with sharing class EmploymentHouseholdController {
    
    /**
     * Get employment details for a contact
     */
    @AuraEnabled(cacheable=true)
    public static List<EmploymentWrapper> getEmploymentDetails(Id contactId) {
        try {
            List<Employment_Details__c> empList = [
                SELECT Id, Name, Employer_Name__c, Job_Title__c, Employment_Status__c,
                       Start_Date__c, End_Date__c, Monthly_Income__c, Employer_Phone__c,
                       Employer_Address__c, Is_Current_Employment__c
                FROM Employment_Details__c
                WHERE Contact__c = :contactId
                ORDER BY Is_Current_Employment__c DESC, Start_Date__c DESC
            ];
            
            List<EmploymentWrapper> wrapperList = new List<EmploymentWrapper>();
            for (Employment_Details__c emp : empList) {
                EmploymentWrapper wrapper = new EmploymentWrapper();
                wrapper.id = emp.Id;
                wrapper.employerName = emp.Employer_Name__c;
                wrapper.jobTitle = emp.Job_Title__c;
                wrapper.employmentStatus = emp.Employment_Status__c;
                wrapper.startDate = emp.Start_Date__c;
                wrapper.endDate = emp.End_Date__c;
                wrapper.monthlyIncome = emp.Monthly_Income__c;
                wrapper.employerPhone = emp.Employer_Phone__c;
                wrapper.employerAddress = emp.Employer_Address__c;
                wrapper.isCurrentEmployment = emp.Is_Current_Employment__c;
                
                wrapperList.add(wrapper);
            }
            
            return wrapperList;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving employment details: ' + e.getMessage());
        }
    }
    
    /**
     * Create employment detail record
     */
    @AuraEnabled
    public static String createEmploymentDetail(String employmentJson, Id contactId) {
        try {
            EmploymentWrapper wrapper = (EmploymentWrapper) JSON.deserialize(
                employmentJson, 
                EmploymentWrapper.class
            );
            
            Employment_Details__c emp = new Employment_Details__c(
                Contact__c = contactId,
                Employer_Name__c = wrapper.employerName,
                Job_Title__c = wrapper.jobTitle,
                Employment_Status__c = wrapper.employmentStatus,
                Start_Date__c = wrapper.startDate,
                End_Date__c = wrapper.endDate,
                Monthly_Income__c = wrapper.monthlyIncome,
                Employer_Phone__c = wrapper.employerPhone,
                Employer_Address__c = wrapper.employerAddress,
                Is_Current_Employment__c = wrapper.isCurrentEmployment
            );
            
            insert emp;
            return emp.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating employment detail: ' + e.getMessage());
        }
    }
    
    /**
     * Update employment detail record
     */
    @AuraEnabled
    public static Boolean updateEmploymentDetail(String employmentJson) {
        try {
            EmploymentWrapper wrapper = (EmploymentWrapper) JSON.deserialize(
                employmentJson, 
                EmploymentWrapper.class
            );
            
            Employment_Details__c emp = [SELECT Id FROM Employment_Details__c 
                                        WHERE Id = :wrapper.id LIMIT 1];
            
            emp.Employer_Name__c = wrapper.employerName;
            emp.Job_Title__c = wrapper.jobTitle;
            emp.Employment_Status__c = wrapper.employmentStatus;
            emp.Start_Date__c = wrapper.startDate;
            emp.End_Date__c = wrapper.endDate;
            emp.Monthly_Income__c = wrapper.monthlyIncome;
            emp.Employer_Phone__c = wrapper.employerPhone;
            emp.Employer_Address__c = wrapper.employerAddress;
            emp.Is_Current_Employment__c = wrapper.isCurrentEmployment;
            
            update emp;
            return true;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error updating employment detail: ' + e.getMessage());
        }
    }
    
    /**
     * Delete employment detail
     */
    @AuraEnabled
    public static Boolean deleteEmploymentDetail(Id employmentId) {
        try {
            delete [SELECT Id FROM Employment_Details__c WHERE Id = :employmentId];
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting employment detail: ' + e.getMessage());
        }
    }
    
    /**
     * Get household background for account
     */
    @AuraEnabled(cacheable=true)
    public static HouseholdWrapper getHouseholdBackground(Id accountId) {
        try {
            List<Household_Background__c> hhList = [
                SELECT Id, Name, Home_Type__c, Number_of_Bedrooms__c, Square_Footage__c,
                       Has_Pool__c, Has_Pets__c, Pet_Details__c, Smoking_Household__c,
                       Number_of_Children_in_Home__c, Children_Ages__c, Home_Safety_Verified__c,
                       Home_Safety_Verification_Date__c, Total_Household_Income__c, Additional_Notes__c
                FROM Household_Background__c
                WHERE Family_Account__c = :accountId
                LIMIT 1
            ];
            
            if (hhList.isEmpty()) {
                return null;
            }
            
            Household_Background__c hh = hhList[0];
            HouseholdWrapper wrapper = new HouseholdWrapper();
            wrapper.id = hh.Id;
            wrapper.homeType = hh.Home_Type__c;
            wrapper.numberOfBedrooms = hh.Number_of_Bedrooms__c != null ? 
                                      Integer.valueOf(hh.Number_of_Bedrooms__c) : 0;
            wrapper.squareFootage = hh.Square_Footage__c != null ? 
                                   Integer.valueOf(hh.Square_Footage__c) : 0;
            wrapper.hasPool = hh.Has_Pool__c;
            wrapper.hasPets = hh.Has_Pets__c;
            wrapper.petDetails = hh.Pet_Details__c;
            wrapper.smokingHousehold = hh.Smoking_Household__c;
            wrapper.numberOfChildrenInHome = hh.Number_of_Children_in_Home__c != null ? 
                                            Integer.valueOf(hh.Number_of_Children_in_Home__c) : 0;
            wrapper.childrenAges = hh.Children_Ages__c;
            wrapper.homeSafetyVerified = hh.Home_Safety_Verified__c;
            wrapper.homeSafetyVerificationDate = hh.Home_Safety_Verification_Date__c;
            wrapper.totalHouseholdIncome = hh.Total_Household_Income__c;
            wrapper.additionalNotes = hh.Additional_Notes__c;
            
            return wrapper;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving household background: ' + e.getMessage());
        }
    }
    
    /**
     * Save or update household background
     */
    @AuraEnabled
    public static String saveHouseholdBackground(String householdJson, Id accountId) {
        try {
            HouseholdWrapper wrapper = (HouseholdWrapper) JSON.deserialize(
                householdJson, 
                HouseholdWrapper.class
            );
            
            List<Household_Background__c> existingHH = [
                SELECT Id FROM Household_Background__c 
                WHERE Family_Account__c = :accountId 
                LIMIT 1
            ];
            
            Household_Background__c hh;
            
            if (existingHH.isEmpty()) {
                // Create new
                hh = new Household_Background__c(
                    Family_Account__c = accountId
                );
            } else {
                // Update existing
                hh = existingHH[0];
            }
            
            hh.Home_Type__c = wrapper.homeType;
            hh.Number_of_Bedrooms__c = wrapper.numberOfBedrooms;
            hh.Square_Footage__c = wrapper.squareFootage;
            hh.Has_Pool__c = wrapper.hasPool;
            hh.Has_Pets__c = wrapper.hasPets;
            hh.Pet_Details__c = wrapper.petDetails;
            hh.Smoking_Household__c = wrapper.smokingHousehold;
            hh.Number_of_Children_in_Home__c = wrapper.numberOfChildrenInHome;
            hh.Children_Ages__c = wrapper.childrenAges;
            hh.Home_Safety_Verified__c = wrapper.homeSafetyVerified;
            hh.Home_Safety_Verification_Date__c = wrapper.homeSafetyVerificationDate;
            hh.Total_Household_Income__c = wrapper.totalHouseholdIncome;
            hh.Additional_Notes__c = wrapper.additionalNotes;
            
            if (existingHH.isEmpty()) {
                insert hh;
            } else {
                update hh;
            }
            
            return hh.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error saving household background: ' + e.getMessage());
        }
    }
    
    /**
     * Wrapper classes
     */
    public class EmploymentWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String employerName;
        @AuraEnabled public String jobTitle;
        @AuraEnabled public String employmentStatus;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Decimal monthlyIncome;
        @AuraEnabled public String employerPhone;
        @AuraEnabled public String employerAddress;
        @AuraEnabled public Boolean isCurrentEmployment;
    }
    
    public class HouseholdWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String homeType;
        @AuraEnabled public Integer numberOfBedrooms;
        @AuraEnabled public Integer squareFootage;
        @AuraEnabled public Boolean hasPool;
        @AuraEnabled public Boolean hasPets;
        @AuraEnabled public String petDetails;
        @AuraEnabled public Boolean smokingHousehold;
        @AuraEnabled public Integer numberOfChildrenInHome;
        @AuraEnabled public String childrenAges;
        @AuraEnabled public Boolean homeSafetyVerified;
        @AuraEnabled public Date homeSafetyVerificationDate;
        @AuraEnabled public Decimal totalHouseholdIncome;
        @AuraEnabled public String additionalNotes;
    }
}