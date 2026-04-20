public class EligibilityAuditService {

    public static final String SCREENER_VERSION = 'v1.0.0';

    public static void createAuditRecord(
        Id candidateId,
        String inputJson,
        String outcome,
        String failureCode,
        Id coordinatorUserId
    ) {
        // Write structured GxP audit entry to platform debug log.
        // In a production validated system, extend this to write to a platform event
        // or dedicated audit custom object per the org's System Validation Plan.
        String safeInput = inputJson != null ? inputJson.left(255) : '';
        System.debug(
            LoggingLevel.INFO,
            'GxP_AUDIT | CandidateId=' + candidateId
            + ' | CoordinatorId=' + coordinatorUserId
            + ' | Version=' + SCREENER_VERSION
            + ' | Outcome=' + outcome
            + ' | FailureCode=' + (String.isBlank(failureCode) ? 'NONE' : failureCode)
            + ' | Timestamp=' + System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
            + ' | Input=' + safeInput
        );
    }
}
