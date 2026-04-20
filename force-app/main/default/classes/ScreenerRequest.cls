public class ScreenerRequest {
    @InvocableVariable(label='Candidate Id' required=true)
    public Id candidateId;

    @InvocableVariable(label='Research Study Id' required=true)
    public Id researchStudyId;

    @InvocableVariable(label='Care Program Id' required=true)
    public Id careProgramId;

    @InvocableVariable(label='Screener JSON Responses' required=false)
    public String screenerJsonResponses;

    @InvocableVariable(label='Prior Cancer History' required=false)
    public String priorCancerHistory;

    @InvocableVariable(label='Current Medications' required=false)
    public String currentMedications;

    @InvocableVariable(label='Coordinator User Id' required=true)
    public Id coordinatorUserId;

    @InvocableVariable(label='Electronic Signature Captured' required=true)
    public Boolean signatureCaptured;
}
