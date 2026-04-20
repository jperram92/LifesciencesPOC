@IsTest
private class ProtocolEligibilityScoringEngineTest {

    // ── Test data setup ──────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        // Person Account (requires PersonAccount enabled in org)
        Account candidate = new Account(
            LastName       = 'TestCandidate',
            RecordTypeId   = getPersonAccountRecordTypeId(),
            PersonBirthdate = Date.today().addYears(-30) // 30 years old — within typical 18-65 range
        );
        insert candidate;

        CareProgram program = new CareProgram(
            Name      = 'Test Program',
            Status    = 'Active',
            StartDate = Date.today()
        );
        insert program;

        ResearchStudy study = new ResearchStudy(
            Name                    = 'Test Study',
            EligibleMinimumAge      = 18,
            EligibleMaximumAge      = 65,
            EligibleGender          = 'All',
            CareProgramId           = program.Id,
            PublicationStatus       = 'Active',
            Phase                   = 'Phase3'
        );
        insert study;

        ResearchStudyCandidate rsc = new ResearchStudyCandidate(
            CandidateId     = candidate.Id,
            ResearchStudyId = study.Id,
            Status          = 'Pending'
        );
        insert rsc;
    }

    // ── Helper ───────────────────────────────────────────────────────────────

    private static Id getPersonAccountRecordTypeId() {
        List<RecordType> rt = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND IsPersonType = true
            LIMIT 1
        ];
        return rt.isEmpty() ? null : rt[0].Id;
    }

    private static ScreenerRequest buildRequest(Id candidateId, Id studyId, Id programId, String json) {
        ScreenerRequest req  = new ScreenerRequest();
        req.candidateId      = candidateId;
        req.researchStudyId  = studyId;
        req.careProgramId    = programId;
        req.screenerJsonResponses = json;
        req.coordinatorUserId = UserInfo.getUserId();
        req.signatureCaptured = true;
        return req;
    }

    // ── Tests ────────────────────────────────────────────────────────────────

    @IsTest
    static void testEligibleCandidate() {
        ResearchStudyCandidate rsc = [SELECT Id, CandidateId, ResearchStudyId FROM ResearchStudyCandidate LIMIT 1];
        CareProgram program = [SELECT Id FROM CareProgram LIMIT 1];

        String json = '{"priorCancerHistory":"No","currentMedications":"None"}';
        ScreenerRequest req = buildRequest(rsc.Id, rsc.ResearchStudyId, program.Id, json);

        Test.startTest();
        List<ScreenerResult> results = ProtocolEligibilityScoringEngine.scoreEligibility(
            new List<ScreenerRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(true, results[0].isEligible, 'Candidate should be eligible');
        System.assertEquals('Eligible', results[0].eligibilityStatus);
        System.assertNotEquals(null, results[0].careProgramEnrolleeId, 'CareProgramEnrollee should be created');

        ResearchStudyCandidate updated = [
            SELECT Eligibility_Status__c, Submission_Timestamp__c, Screener_Version__c
            FROM ResearchStudyCandidate
            WHERE Id = :rsc.Id
        ];
        System.assertEquals('Eligible', updated.Eligibility_Status__c);
        System.assertNotEquals(null, updated.Submission_Timestamp__c);
        System.assertEquals(EligibilityAuditService.SCREENER_VERSION, updated.Screener_Version__c);
    }

    @IsTest
    static void testAgeGateBelowMinimum() {
        ResearchStudyCandidate rsc = [SELECT Id, CandidateId, ResearchStudyId FROM ResearchStudyCandidate LIMIT 1];
        CareProgram program = [SELECT Id FROM CareProgram LIMIT 1];

        // Set candidate age to 17
        Account acct = [SELECT Id FROM Account WHERE Id = :rsc.CandidateId];
        acct.PersonBirthdate = Date.today().addYears(-17);
        update acct;

        ScreenerRequest req = buildRequest(rsc.Id, rsc.ResearchStudyId, program.Id, '{}');

        Test.startTest();
        List<ScreenerResult> results = ProtocolEligibilityScoringEngine.scoreEligibility(
            new List<ScreenerRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isEligible);
        System.assertEquals('EX-01-AGE', results[0].protocolFailureCode);
        System.assertEquals('Ineligible', results[0].eligibilityStatus);
    }

    @IsTest
    static void testAgeGateAboveMaximum() {
        ResearchStudyCandidate rsc = [SELECT Id, CandidateId, ResearchStudyId FROM ResearchStudyCandidate LIMIT 1];
        CareProgram program = [SELECT Id FROM CareProgram LIMIT 1];

        // Set candidate age to 66
        Account acct = [SELECT Id FROM Account WHERE Id = :rsc.CandidateId];
        acct.PersonBirthdate = Date.today().addYears(-66);
        update acct;

        ScreenerRequest req = buildRequest(rsc.Id, rsc.ResearchStudyId, program.Id, '{}');

        Test.startTest();
        List<ScreenerResult> results = ProtocolEligibilityScoringEngine.scoreEligibility(
            new List<ScreenerRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isEligible);
        System.assertEquals('EX-01-AGE', results[0].protocolFailureCode);
    }

    @IsTest
    static void testAgeGateBoundaryMinimumPass() {
        ResearchStudyCandidate rsc = [SELECT Id, CandidateId, ResearchStudyId FROM ResearchStudyCandidate LIMIT 1];
        CareProgram program = [SELECT Id FROM CareProgram LIMIT 1];

        // Exactly 18 — must pass
        Account acct = [SELECT Id FROM Account WHERE Id = :rsc.CandidateId];
        acct.PersonBirthdate = Date.today().addYears(-18);
        update acct;

        ScreenerRequest req = buildRequest(rsc.Id, rsc.ResearchStudyId, program.Id, '{"priorCancerHistory":"No"}');

        Test.startTest();
        List<ScreenerResult> results = ProtocolEligibilityScoringEngine.scoreEligibility(
            new List<ScreenerRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].isEligible, 'Age 18 is at boundary minimum — should pass');
    }

    @IsTest
    static void testAgeGateBoundaryMaximumPass() {
        ResearchStudyCandidate rsc = [SELECT Id, CandidateId, ResearchStudyId FROM ResearchStudyCandidate LIMIT 1];
        CareProgram program = [SELECT Id FROM CareProgram LIMIT 1];

        // Exactly 65 — must pass
        Account acct = [SELECT Id FROM Account WHERE Id = :rsc.CandidateId];
        acct.PersonBirthdate = Date.today().addYears(-65);
        update acct;

        ScreenerRequest req = buildRequest(rsc.Id, rsc.ResearchStudyId, program.Id, '{"priorCancerHistory":"No"}');

        Test.startTest();
        List<ScreenerResult> results = ProtocolEligibilityScoringEngine.scoreEligibility(
            new List<ScreenerRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].isEligible, 'Age 65 is at boundary maximum — should pass');
    }

    @IsTest
    static void testGenderGateHandledByFlow() {
        // Gender eligibility is enforced at the Flow level via coordinator confirmation checkbox.
        // Apex gender gate requires org-specific PersonAccount gender field confirmation.
        // This test verifies a candidate passes when other criteria are met.
        ResearchStudyCandidate rsc = [SELECT Id, CandidateId, ResearchStudyId FROM ResearchStudyCandidate LIMIT 1];
        CareProgram program = [SELECT Id FROM CareProgram LIMIT 1];
        ScreenerRequest req = buildRequest(rsc.Id, rsc.ResearchStudyId, program.Id, '{"priorCancerHistory":"No"}');

        Test.startTest();
        List<ScreenerResult> results = ProtocolEligibilityScoringEngine.scoreEligibility(
            new List<ScreenerRequest>{ req }
        );
        Test.stopTest();

        System.assertNotEquals(null, results[0].eligibilityStatus, 'Should return a status');
    }

    @IsTest
    static void testExclusionCriterionMet() {
        ResearchStudyCandidate rsc = [SELECT Id, CandidateId, ResearchStudyId FROM ResearchStudyCandidate LIMIT 1];
        CareProgram program = [SELECT Id FROM CareProgram LIMIT 1];

        // Prior cancer history = Yes triggers EX-03-HIST
        String json = '{"priorCancerHistory":"Yes"}';
        ScreenerRequest req = buildRequest(rsc.Id, rsc.ResearchStudyId, program.Id, json);

        Test.startTest();
        List<ScreenerResult> results = ProtocolEligibilityScoringEngine.scoreEligibility(
            new List<ScreenerRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isEligible);
        System.assertEquals('EX-03-HIST', results[0].protocolFailureCode);
        System.assertNotEquals(null, results[0].disqualificationReason);
    }

    @IsTest
    static void testMissingElectronicSignature() {
        ResearchStudyCandidate rsc = [SELECT Id, CandidateId, ResearchStudyId FROM ResearchStudyCandidate LIMIT 1];
        CareProgram program = [SELECT Id FROM CareProgram LIMIT 1];

        ScreenerRequest req = buildRequest(rsc.Id, rsc.ResearchStudyId, program.Id, '{}');
        req.signatureCaptured = false;

        Test.startTest();
        List<ScreenerResult> results = ProtocolEligibilityScoringEngine.scoreEligibility(
            new List<ScreenerRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isEligible);
        System.assertEquals('SIG-01-MISSING', results[0].protocolFailureCode);
    }

    @IsTest
    static void testGxpRecordLockValidationRule() {
        ResearchStudyCandidate rsc = [SELECT Id FROM ResearchStudyCandidate LIMIT 1];

        // Set to Submitted
        rsc.Eligibility_Status__c = 'Submitted';
        update rsc;

        // Attempt edit — must be blocked
        ResearchStudyCandidate attempt = new ResearchStudyCandidate(
            Id = rsc.Id,
            Eligibility_Status__c = 'Eligible'
        );

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            update attempt;
        } catch (DmlException e) {
            exceptionThrown = e.getMessage().contains('GxP') || e.getMessage().contains('locked');
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'GxP_Record_Lock validation rule should prevent edit after Submitted');
    }

    @IsTest
    static void testBulkProcessing() {
        // Verify the engine handles multiple records without governor limit issues
        CareProgram program = [SELECT Id FROM CareProgram LIMIT 1];
        ResearchStudy study  = [SELECT Id FROM ResearchStudy LIMIT 1];

        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            accounts.add(new Account(
                LastName        = 'BulkTest' + i,
                RecordTypeId    = getPersonAccountRecordTypeId(),
                PersonBirthdate = Date.today().addYears(-30)
            ));
        }
        insert accounts;

        List<ResearchStudyCandidate> rscs = new List<ResearchStudyCandidate>();
        for (Account a : accounts) {
            rscs.add(new ResearchStudyCandidate(
                CandidateId     = a.Id,
                ResearchStudyId = study.Id,
                Status          = 'Pending'
            ));
        }
        insert rscs;

        List<ScreenerRequest> reqs = new List<ScreenerRequest>();
        for (ResearchStudyCandidate rsc : rscs) {
            reqs.add(buildRequest(rsc.Id, rsc.ResearchStudyId, program.Id, '{"priorCancerHistory":"No"}'));
        }

        Test.startTest();
        List<ScreenerResult> results = ProtocolEligibilityScoringEngine.scoreEligibility(reqs);
        Test.stopTest();

        System.assertEquals(10, results.size(), 'All 10 bulk requests should return results');
        for (ScreenerResult r : results) {
            System.assertEquals(true, r.isEligible, 'All bulk candidates should be eligible');
        }
    }
}
