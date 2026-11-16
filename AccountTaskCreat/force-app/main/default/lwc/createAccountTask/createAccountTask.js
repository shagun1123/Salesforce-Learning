import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import ID_FIELD from '@salesforce/schema/Account.Id';
import PROMPT_FIELD from '@salesforce/schema/Account.CreateTask__c';

export default class TaskTrigger extends LightningElement {
    @api recordId;
    showFlowModal = false;

    
    @wire(getRecord, { recordId: '$recordId', fields: [PROMPT_FIELD] })
    wiredAccount({ error, data }) {
        if (data) {
            const needsPrompt = getFieldValue(data, PROMPT_FIELD);
            if (needsPrompt) {
                this.showFlowModal = true;
            }
        } else if (error) {
            console.error('Error loading account', error);
        }
    }

    
    get flowInputVariables() {
        return [{
            name: 'recordId',
            type: 'String',
            value: this.recordId
        }];
    }

    
    handleFlowStatusChange(event) {
        if (event.detail.status === 'FINISHED' || event.detail.status === 'FINISHED_SCREEN') {
            this.resetTriggerField();
        }
    }

   
    async resetTriggerField() {
        this.showFlowModal = false;
        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[PROMPT_FIELD.fieldApiName] = false;

        const recordInput = { fields };
        try {
            await updateRecord(recordInput);
        } catch (error) {
            console.error('Error resetting trigger field', error);
        }
    }
}
