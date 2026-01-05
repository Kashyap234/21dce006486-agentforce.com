import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import submitApplication from '@salesforce/apex/GuestApplicationController.submitApplication';

export default class EnhancedFosterApplicationForm extends LightningElement {
    @track currentStep = 'step1';
    @track showSuccess = false;
    @track errorMessage = '';
    @track isSubmitting = false;

    @track primaryApplicant = {
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        company: '',
        street: '',
        city: '',
        state: '',
        postalCode: '',
        applicationType: ''
    };

    @track familyMembers = [];
    @track currentMember = this.getEmptyMember();

    @track householdInfo = {
        homeType: '',
        bedrooms: 0,
        squareFootage: 0,
        hasPool: false,
        hasPets: false,
        petDetails: '',
        smoking: false
    };

    applicationTypeOptions = [
        { label: 'Foster Parent', value: 'Foster Parent' },
        { label: 'Caseworker', value: 'Caseworker' }
    ];

    relationshipOptions = [
        { label: 'Spouse', value: 'Spouse' },
        { label: 'Partner', value: 'Partner' },
        { label: 'Adult Child', value: 'Child' },
        { label: 'Parent', value: 'Parent' },
        { label: 'Sibling', value: 'Sibling' },
        { label: 'Other Relative', value: 'Other Relative' },
        { label: 'Other', value: 'Other' }
    ];

    homeTypeOptions = [
        { label: 'Own', value: 'Own' },
        { label: 'Rent', value: 'Rent' },
        { label: 'With Family', value: 'With Family' },
        { label: 'Other', value: 'Other' }
    ];

    // Check if applicant is a caseworker
    get isCaseworker() {
        return this.primaryApplicant.applicationType === 'Caseworker';
    }

    // Step checks
    get isStep1() { return this.currentStep === 'step1'; }
    get isStep2() { return this.currentStep === 'step2'; }
    get isStep3() { return this.currentStep === 'step3'; }
    get isStep4() { return this.currentStep === 'step4'; }

    get hasFamilyMembers() {
        return this.familyMembers && this.familyMembers.length > 0;
    }

    get householdInfo_hasPetsLabel() {
        return this.householdInfo.hasPets ? 'Yes' : 'No';
    }

    /**
     * Handle primary applicant field changes
     */
    handlePrimaryFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const oldType = this.primaryApplicant.applicationType;
        this.primaryApplicant[field] = event.target.value;
        
        // If application type changed, reset to step 1
        if (field === 'applicationType' && oldType !== event.target.value) {
            this.currentStep = 'step1';
        }
    }

    /**
     * Handle family member field changes
     */
    handleMemberFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this.currentMember[field] = event.target.value;
    }

    /**
     * Handle household field changes
     */
    handleHouseholdFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.householdInfo[field] = value;
    }

    /**
     * Add family member to list
     */
    handleAddFamilyMember() {
        if (!this.currentMember.firstName || !this.currentMember.lastName) {
            this.showToast('Error', 'Please enter first and last name', 'error');
            return;
        }

        // Add temp ID for tracking
        this.currentMember.tempId = Date.now();
        
        // Add to array
        this.familyMembers = [...this.familyMembers, { ...this.currentMember }];
        
        // Reset form
        this.currentMember = this.getEmptyMember();
        
        this.showToast('Success', 'Family member added', 'success');
    }

    /**
     * Remove family member from list
     */
    handleRemoveMember(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.familyMembers = this.familyMembers.filter((_, i) => i !== index);
        this.showToast('Success', 'Family member removed', 'success');
    }

    /**
     * Navigation: Next
     */
    handleNext() {
        // Validate current step
        if (this.currentStep === 'step1') {
            if (!this.validateStep1()) {
                return;
            }
            
            // If caseworker, skip to review step (step4)
            if (this.isCaseworker) {
                this.currentStep = 'step4';
            } else {
                this.currentStep = 'step2';
            }
        } else if (this.currentStep === 'step2') {
            this.currentStep = 'step3';
        } else if (this.currentStep === 'step3') {
            this.currentStep = 'step4';
        }
        
        this.errorMessage = '';
        window.scrollTo(0, 0);
    }

    /**
     * Navigation: Previous
     */
    handlePrevious() {
        if (this.currentStep === 'step4') {
            // If caseworker, go back to step1
            if (this.isCaseworker) {
                this.currentStep = 'step1';
            } else {
                this.currentStep = 'step3';
            }
        } else if (this.currentStep === 'step3') {
            this.currentStep = 'step2';
        } else if (this.currentStep === 'step2') {
            this.currentStep = 'step1';
        }
        
        this.errorMessage = '';
        window.scrollTo(0, 0);
    }

    /**
     * Validate step 1
     */
    validateStep1() {
        if (!this.primaryApplicant.firstName || !this.primaryApplicant.lastName || 
            !this.primaryApplicant.email || !this.primaryApplicant.phone || 
            !this.primaryApplicant.applicationType) {
            this.errorMessage = 'Please fill in all required fields';
            return false;
        }
        return true;
    }

    /**
     * Final submit
     */
    async handleFinalSubmit() {
        this.isSubmitting = true;
        this.errorMessage = '';

        try {
            const applicationData = {
                primaryApplicant: this.primaryApplicant,
                // Only include family members and household info for Foster Parents
                familyMembers: this.isCaseworker ? [] : this.familyMembers,
                householdInfo: this.isCaseworker ? {} : this.householdInfo
            };

            await submitApplication({ applicationDataJson: JSON.stringify(applicationData) });

            this.showSuccess = true;
            this.showToast('Success', 'Application submitted successfully!', 'success');
            window.scrollTo(0, 0);

        } catch (error) {
            this.errorMessage = 'Error submitting application: ' + (error.body?.message || error.message);
            this.showToast('Error', this.errorMessage, 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    /**
     * Handle new application
     */
    handleNewApplication() {
        this.showSuccess = false;
        this.currentStep = 'step1';
        this.primaryApplicant = {
            firstName: '',
            lastName: '',
            email: '',
            phone: '',
            company: '',
            street: '',
            city: '',
            state: '',
            postalCode: '',
            applicationType: ''
        };
        this.familyMembers = [];
        this.currentMember = this.getEmptyMember();
        this.householdInfo = {
            homeType: '',
            bedrooms: 0,
            squareFootage: 0,
            hasPool: false,
            hasPets: false,
            petDetails: '',
            smoking: false
        };
        this.errorMessage = '';
    }

    /**
     * Get empty member object
     */
    getEmptyMember() {
        return {
            firstName: '',
            lastName: '',
            email: '',
            phone: '',
            birthdate: null,
            relationship: '',
            employerName: '',
            jobTitle: '',
            monthlyIncome: null
        };
    }

    /**
     * Show toast
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
}