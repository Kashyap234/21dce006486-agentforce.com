import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getFamilyMembers from '@salesforce/apex/FamilyMemberController.getFamilyMembers';
import createFamilyMember from '@salesforce/apex/FamilyMemberController.createFamilyMember';
import updateFamilyMember from '@salesforce/apex/FamilyMemberController.updateFamilyMember';
import deleteFamilyMember from '@salesforce/apex/FamilyMemberController.deleteFamilyMember';
import getPrimaryContactInfo from '@salesforce/apex/FamilyMemberController.getPrimaryContactInfo';

export default class FamilyMemberManagement extends LightningElement {
    @track familyMembers = [];
    @track primaryContactInfo;
    @track showModal = false;
    @track isLoading = false;
    @track isSaving = false;
    @track errorMessage = '';
    @track currentMember = this.getEmptyMember();
    @track isEditMode = false;
    
    wiredFamilyMembersResult;
    wiredPrimaryContactResult;

    // Relationship picklist options
    relationshipOptions = [
        { label: 'Spouse', value: 'Spouse' },
        { label: 'Partner', value: 'Partner' },
        { label: 'Child', value: 'Child' },
        { label: 'Parent', value: 'Parent' },
        { label: 'Sibling', value: 'Sibling' },
        { label: 'Other Relative', value: 'Other Relative' },
        { label: 'Other', value: 'Other' }
    ];

    /**
     * Wire to get primary contact info
     */
    @wire(getPrimaryContactInfo)
    wiredPrimaryContact(result) {
        this.wiredPrimaryContactResult = result;
        if (result.data) {
            this.primaryContactInfo = result.data;
        } else if (result.error) {
            this.showToast('Error', 'Error loading primary contact information', 'error');
        }
    }

    /**
     * Wire to get family members
     */
    @wire(getFamilyMembers)
    wiredFamilyMembers(result) {
        this.wiredFamilyMembersResult = result;
        this.isLoading = true;
        
        if (result.data) {
            this.familyMembers = result.data;
            this.isLoading = false;
            this.errorMessage = '';
        } else if (result.error) {
            this.errorMessage = 'Error loading family members: ' + this.getErrorMessage(result.error);
            this.isLoading = false;
        }
    }

    /**
     * Check if there are family members
     */
    get hasFamilyMembers() {
        return this.familyMembers && this.familyMembers.length > 0;
    }

    /**
     * Get modal title based on mode
     */
    get modalTitle() {
        return this.isEditMode ? 'Edit Family Member' : 'Add Family Member';
    }

    /**
     * Handle add member button click
     */
    handleAddMember() {
        this.isEditMode = false;
        this.currentMember = this.getEmptyMember();
        this.showModal = true;
    }

    /**
     * Handle edit member button click
     */
    handleEditMember(event) {
        const memberId = event.currentTarget.dataset.id;
        const member = this.familyMembers.find(m => m.id === memberId);
        
        if (member) {
            this.isEditMode = true;
            this.currentMember = { ...member };
            this.showModal = true;
        }
    }

    /**
     * Handle delete member button click
     */
    async handleDeleteMember(event) {
        const memberId = event.currentTarget.dataset.id;
        
        if (confirm('Are you sure you want to delete this family member?')) {
            this.isLoading = true;
            
            try {
                await deleteFamilyMember({ familyMemberId: memberId });
                
                this.showToast('Success', 'Family member deleted successfully', 'success');
                
                // Refresh the list
                await refreshApex(this.wiredFamilyMembersResult);
                
            } catch (error) {
                this.showToast('Error', this.getErrorMessage(error), 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    /**
     * Handle field changes in modal
     */
    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.detail.value || event.target.value;
        
        this.currentMember = {
            ...this.currentMember,
            [field]: value
        };
    }

    /**
     * Handle save member
     */
    async handleSaveMember() {
        // Validate required fields
        if (!this.currentMember.firstName || !this.currentMember.lastName || !this.currentMember.relationship) {
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }

        this.isSaving = true;

        try {
            if (this.isEditMode) {
                // Update existing member
                await updateFamilyMember({ 
                    familyMemberJson: JSON.stringify(this.currentMember) 
                });
                this.showToast('Success', 'Family member updated successfully', 'success');
            } else {
                // Create new member
                await createFamilyMember({ 
                    familyMemberJson: JSON.stringify(this.currentMember) 
                });
                this.showToast('Success', 'Family member added successfully', 'success');
            }

            // Refresh the list
            await refreshApex(this.wiredFamilyMembersResult);
            
            // Close modal
            this.handleCloseModal();

        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    /**
     * Handle close modal
     */
    handleCloseModal() {
        this.showModal = false;
        this.currentMember = this.getEmptyMember();
        this.isEditMode = false;
    }

    /**
     * Get empty member object
     */
    getEmptyMember() {
        return {
            id: null,
            firstName: '',
            lastName: '',
            email: '',
            phone: '',
            mobilePhone: '',
            birthdate: null,
            relationship: '',
            backgroundCheckStatus: 'Pending',
            trainingCompleted: false,
            homeStudyCompleted: false
        };
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