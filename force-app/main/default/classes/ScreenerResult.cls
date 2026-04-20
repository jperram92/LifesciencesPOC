public class ScreenerResult {
    @InvocableVariable(label='Is Eligible')
    public Boolean isEligible;

    @InvocableVariable(label='Eligibility Status')
    public String eligibilityStatus;

    @InvocableVariable(label='Protocol Failure Code')
    public String protocolFailureCode;

    @InvocableVariable(label='Disqualification Reason')
    public String disqualificationReason;

    @InvocableVariable(label='Screener Version')
    public String screenerVersion;

    @InvocableVariable(label='Submission Timestamp')
    public DateTime submissionTimestamp;

    @InvocableVariable(label='Care Program Enrollee Id')
    public Id careProgramEnrolleeId;

    @InvocableVariable(label='Error Message')
    public String errorMessage;
}
