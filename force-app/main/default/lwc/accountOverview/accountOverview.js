import { LightningElement, api, wire, track } from 'lwc';
import getAccountOverview from '@salesforce/apex/AccountOverviewController.getAccountOverview';

export default class AccountOverview extends LightningElement {
    @api recordId; // Account Id from record page
    @track accountOverview;
    @track isLoading = true;
    @track error;

    @wire(getAccountOverview, { accountId: '$recordId' })
    wiredAccountOverview({ error, data }) {
        this.isLoading = true;
        
        if (data) {
            // Create a deep copy of the data to avoid mutating the wire's read-only proxy
            const dataCopy = JSON.parse(JSON.stringify(data));
            this.accountOverview = this.enrichContactData(dataCopy);
            this.isLoading = false;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.accountOverview = undefined;
            this.isLoading = false;
        }
    }

    /**
     * Enrich contact data with additional computed properties
     */
    enrichContactData(data) {
        if (data.contacts) {
            data.contacts = data.contacts.map(contact => {
                return {
                    ...contact,
                    contactLink: `/${contact.contactId}`,
                    iconName: contact.recordType === 'Primary Contact' ? 
                             'standard:avatar' : 'standard:contact',
                    trainingIcon: contact.trainingCompleted ? 
                                 'utility:check' : 'utility:close',
                    homeStudyIcon: contact.homeStudyCompleted ? 
                                   'utility:check' : 'utility:close'
                };
            });
        }
        return data;
    }

    /**
     * Get household safety icon
     */
    get householdSafetyIcon() {
        return this.accountOverview?.householdInfo?.homeSafetyVerified ? 
               'utility:check' : 'utility:close';
    }
}