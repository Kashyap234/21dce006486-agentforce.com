import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAccountOverview from '@salesforce/apex/AccountOverviewController.getAccountOverview';
import assignCaseworkerToAccount from '@salesforce/apex/AccountOverviewController.assignCaseworkerToAccount';
import getAvailableCaseworkers from '@salesforce/apex/CaseworkerAssignmentService.getAvailableCaseworkers';

export default class AccountOverview extends LightningElement {
    @api recordId; // Account Id from record page
    @track accountOverview;
    @track isLoading = true;
    @track error;
    @track showCaseworkerModal = false;
    @track availableCaseworkers = [];
    @track selectedCaseworkerId;
    @track isLoadingCaseworkers = false;
    @track isSavingCaseworker = false;
    
    wiredAccountOverviewResult;

    @wire(getAccountOverview, { accountId: '$recordId' })
    wiredAccountOverview(result) {
        this.wiredAccountOverviewResult = result;
        this.isLoading = true;
        
        if (result.data) {
            // Create a deep copy of the data to avoid mutating the wire's read-only proxy
            const dataCopy = JSON.parse(JSON.stringify(result.data));
            this.accountOverview = this.enrichContactData(dataCopy);
            this.isLoading = false;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
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

    /**
     * Get caseworker options for combobox
     */
    get caseworkerOptions() {
        if (!this.availableCaseworkers) return [];
        
        return this.availableCaseworkers.map(cw => {
            const label = `${cw.name} (${cw.currentCaseLoad}/${cw.maximumCaseLoad}) - ${cw.availabilityStatus}`;
            return {
                label: label,
                value: cw.id
            };
        });
    }

    /**
     * Get selected caseworker details
     */
    get selectedCaseworkerDetails() {
        if (!this.selectedCaseworkerId || !this.availableCaseworkers) return null;
        
        return this.availableCaseworkers.find(cw => cw.id === this.selectedCaseworkerId);
    }

    /**
     * Handle assign caseworker button click
     */
    async handleAssignCaseworker() {
        this.showCaseworkerModal = true;
        this.isLoadingCaseworkers = true;
        
        try {
            const result = await getAvailableCaseworkers();
            this.availableCaseworkers = result;
            
            // Pre-select current caseworker if exists
            if (this.accountOverview?.primaryCaseworkerId) {
                this.selectedCaseworkerId = this.accountOverview.primaryCaseworkerId;
            }
        } catch (error) {
            this.showToast('Error', 'Error loading caseworkers: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoadingCaseworkers = false;
        }
    }

    /**
     * Handle caseworker selection change
     */
    handleCaseworkerSelection(event) {
        this.selectedCaseworkerId = event.detail.value;
    }

    /**
     * Handle close caseworker modal
     */
    handleCloseCaseworkerModal() {
        this.showCaseworkerModal = false;
        this.selectedCaseworkerId = null;
        this.availableCaseworkers = [];
    }

    /**
     * Handle save caseworker assignment
     */
    async handleSaveCaseworker() {
        if (!this.selectedCaseworkerId) {
            this.showToast('Error', 'Please select a caseworker', 'error');
            return;
        }

        this.isSavingCaseworker = true;

        try {
            await assignCaseworkerToAccount({
                accountId: this.recordId,
                caseworkerId: this.selectedCaseworkerId
            });

            this.showToast('Success', 'Caseworker assigned successfully', 'success');
            
            // Refresh the account overview
            await refreshApex(this.wiredAccountOverviewResult);
            
            // Close modal
            this.handleCloseCaseworkerModal();

        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isSavingCaseworker = false;
        }
    }

    /**
     * Show toast message
     */
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    /**
     * Extract error message from error object
     */
    getErrorMessage(error) {
        if (error.body && error.body.message) {
            return error.body.message;
        } else if (error.message) {
            return error.message;
        } else if (typeof error === 'string') {
            return error;
        }
        return 'An unknown error occurred';
    }
}