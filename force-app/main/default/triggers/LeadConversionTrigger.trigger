/**
 * Trigger: LeadConversionTrigger
 * Object: Lead
 * Purpose: Automatically convert Leads to Account/Contact when status changes to "Eligible for Foster"
 */
trigger LeadConversionTrigger on Lead (after update) {
    // Delegate to handler class for better code organization
    LeadConversionHandler.handleLeadConversion(Trigger.new, Trigger.oldMap);
}