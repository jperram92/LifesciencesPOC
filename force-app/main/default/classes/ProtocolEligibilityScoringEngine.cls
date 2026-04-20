public class ProtocolEligibilityScoringEngine {

    private static final String VERSION = EligibilityAuditService.SCREENER_VERSION;

    // Failure codes — mapped to Traceability Matrix entries
    private static final String FC_AGE    = 'EX-01-AGE';
    private static final String FC_GENDER = 'EX-02-GENDER';
    private static final String FC_HIST   = 'EX-03-HIST';
    private static final String FC_INCL   = 'IN-01-MISSING';

    @InvocableMethod(label='Score Protocol Eligibility' category='Clinical Trials')
    public static List<ScreenerResult> scoreEligibility(List<ScreenerRequest> requests) {
        List<ScreenerResult> results = new List<ScreenerResult>();

        // Collect all IDs for bulkified SOQL — no queries inside the loop
        Set<Id> candidateIds   = new Set<Id>();
        Set<Id> studyIds       = new Set<Id>();

        for (ScreenerRequest req : requests) {
            candidateIds.add(req.candidateId);
            studyIds.add(req.researchStudyId);
        }

        Map<Id, ResearchStudyCandidate> candidateMap = new Map<Id, ResearchStudyCandidate>(
            [SELECT Id, CandidateId, ResearchStudyId
             FROM ResearchStudyCandidate
             WHERE Id IN :candidateIds]
        );

        Map<Id, ResearchStudy> studyMap = new Map<Id, ResearchStudy>(
            [SELECT Id, EligibleMinimumAge, EligibleMaximumAge, EligibleGender,
                    InclusionExclusionCriteria, CareProgramId
             FROM ResearchStudy
             WHERE Id IN :studyIds]
        );

        // Load candidate Person Accounts for DOB and gender
        Set<Id> accountIds = new Set<Id>();
        for (ResearchStudyCandidate rsc : candidateMap.values()) {
            if (rsc.CandidateId != null) {
                accountIds.add(rsc.CandidateId);
            }
        }

        Map<Id, Account> accountMap = new Map<Id, Account>(
            [SELECT Id, PersonBirthdate
             FROM Account
             WHERE Id IN :accountIds AND IsPersonAccount = true]
        );

        List<ResearchStudyCandidate> toUpdate = new List<ResearchStudyCandidate>();
        List<CareProgramEnrollee> toInsert    = new List<CareProgramEnrollee>();

        for (ScreenerRequest req : requests) {
            ScreenerResult result = new ScreenerResult();
            result.screenerVersion     = VERSION;
            result.submissionTimestamp = System.now();

            try {
                if (!req.signatureCaptured) {
                    result.isEligible             = false;
                    result.eligibilityStatus      = 'Ineligible';
                    result.protocolFailureCode    = 'SIG-01-MISSING';
                    result.disqualificationReason = 'Electronic signature was not captured. Submission rejected per 21 CFR Part 11.';
                    results.add(result);
                    continue;
                }

                ResearchStudy study = studyMap.get(req.researchStudyId);
                ResearchStudyCandidate rsc = candidateMap.get(req.candidateId);

                if (study == null || rsc == null) {
                    result.isEligible    = false;
                    result.eligibilityStatus = 'Ineligible';
                    result.errorMessage  = 'Study or Candidate record not found.';
                    results.add(result);
                    continue;
                }

                Account candidate = accountMap.get(rsc.CandidateId);

                // === AGE GATE ===
                if (candidate != null && candidate.PersonBirthdate != null) {
                    Integer ageYears = calculateAge(candidate.PersonBirthdate);

                    if (study.EligibleMinimumAge != null && ageYears < Integer.valueOf(study.EligibleMinimumAge)) {
                        result.isEligible             = false;
                        result.eligibilityStatus      = 'Ineligible';
                        result.protocolFailureCode    = FC_AGE;
                        result.disqualificationReason = 'Candidate age ' + ageYears
                            + ' is below the protocol minimum of ' + study.EligibleMinimumAge + ' years.';
                        buildUpdateRecord(rsc, result, toUpdate);
                        EligibilityAuditService.createAuditRecord(req.candidateId, req.screenerJsonResponses, 'Ineligible', FC_AGE, req.coordinatorUserId);
                        results.add(result);
                        continue;
                    }

                    if (study.EligibleMaximumAge != null && ageYears > Integer.valueOf(study.EligibleMaximumAge)) {
                        result.isEligible             = false;
                        result.eligibilityStatus      = 'Ineligible';
                        result.protocolFailureCode    = FC_AGE;
                        result.disqualificationReason = 'Candidate age ' + ageYears
                            + ' exceeds the protocol maximum of ' + study.EligibleMaximumAge + ' years.';
                        buildUpdateRecord(rsc, result, toUpdate);
                        EligibilityAuditService.createAuditRecord(req.candidateId, req.screenerJsonResponses, 'Ineligible', FC_AGE, req.coordinatorUserId);
                        results.add(result);
                        continue;
                    }
                }

                // Gender gate is enforced in the Flow (coordinator confirms via checkbox).
                // Org-specific gender field name varies across HC implementations;
                // extend this block once the correct API name is confirmed for this org.

                // Build JSON from individual fields for audit storage
                req.screenerJsonResponses = buildAuditJson(req.priorCancerHistory, req.currentMedications);

                // === EXCLUSION CRITERIA ===
                String failCode = evaluateExclusionCriteria(req.priorCancerHistory);
                if (String.isNotBlank(failCode)) {
                    result.isEligible             = false;
                    result.eligibilityStatus      = 'Ineligible';
                    result.protocolFailureCode    = failCode;
                    result.disqualificationReason = 'Exclusion criterion met: ' + failCode
                        + '. Refer to protocol for details.';
                    buildUpdateRecord(rsc, result, toUpdate);
                    EligibilityAuditService.createAuditRecord(req.candidateId, req.screenerJsonResponses, 'Ineligible', failCode, req.coordinatorUserId);
                    results.add(result);
                    continue;
                }

                // === ELIGIBLE PATH ===
                result.isEligible        = true;
                result.eligibilityStatus = 'Eligible';

                // Build CareProgramEnrollee
                CareProgramEnrollee enrollee = new CareProgramEnrollee(
                    CareProgramId             = study.CareProgramId,
                    AccountId                 = rsc.CandidateId,
                    ResearchStudyCandidateId  = rsc.Id,
                    Status                    = 'Active',
                    EnrolleeType              = 'New'
                );
                toInsert.add(enrollee);

                buildUpdateRecord(rsc, result, toUpdate);
                EligibilityAuditService.createAuditRecord(req.candidateId, req.screenerJsonResponses, 'Eligible', null, req.coordinatorUserId);
                results.add(result);

            } catch (Exception ex) {
                result.isEligible    = false;
                result.errorMessage  = ex.getMessage();
                result.eligibilityStatus = 'In Progress';
                results.add(result);
            }
        }

        // Bulkified DML
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
            // Wire enrollee IDs back to results
            Integer enrolleeIdx = 0;
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isEligible == true && enrolleeIdx < toInsert.size()) {
                    results[i].careProgramEnrolleeId = toInsert[enrolleeIdx].Id;
                    enrolleeIdx++;
                }
            }
        }

        return results;
    }

    private static void buildUpdateRecord(
        ResearchStudyCandidate rsc,
        ScreenerResult result,
        List<ResearchStudyCandidate> toUpdate
    ) {
        ResearchStudyCandidate upd = new ResearchStudyCandidate(
            Id                          = rsc.Id,
            Eligibility_Status__c       = result.eligibilityStatus,
            Disqualification_Reason__c  = result.disqualificationReason,
            Protocol_Failure_Code__c    = result.protocolFailureCode,
            Screener_Version__c         = result.screenerVersion,
            Submission_Timestamp__c     = result.submissionTimestamp
        );
        toUpdate.add(upd);
    }

    private static Integer calculateAge(Date birthdate) {
        Date today = Date.today();
        Integer years = today.year() - birthdate.year();
        if (today.month() < birthdate.month()
            || (today.month() == birthdate.month() && today.day() < birthdate.day())) {
            years--;
        }
        return years;
    }

    private static String buildAuditJson(String priorCancerHistory, String currentMedications) {
        return '{"priorCancerHistory":"' + String.escapeSingleQuotes(priorCancerHistory != null ? priorCancerHistory : '')
            + '","currentMedications":"' + String.escapeSingleQuotes(currentMedications != null ? currentMedications : '')
            + '"}';
    }

    private static String evaluateExclusionCriteria(String priorCancerHistory) {
        if (String.isBlank(priorCancerHistory)) {
            return null;
        }
        if (priorCancerHistory.equalsIgnoreCase('Yes')) {
            return FC_HIST;
        }
        // Extend: add additional protocol-specific exclusion checks here.
        // Each check maps to a Traceability Matrix entry via the FC_* constant.
        return null;
    }
}
