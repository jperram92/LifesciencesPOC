# Clinical Trial Eligibility Screener — Solution Design Document

**Project:** LifesciencesPOC  
**Version:** 1.0  
**API Version:** 66.0  
**Date:** 2026-04-19  
**Author:** James Perram  

---

## 1. Executive Summary

This document describes the architecture and implementation of the **Protocol Eligibility Screener** built on Salesforce Life Sciences Cloud (LSC). The solution automates the clinical trial recruitment funnel — replacing fragmented, manual pre-screening with a validated, GxP-compliant digital workflow that satisfies 21 CFR Part 11 requirements.

The system establishes a "single digital thread" from the first candidate interaction through to formal enrollment, using standard LSC objects exclusively and the Einstein Trust Layer for AI-assisted decision transparency.

---

## 2. Regulatory & Compliance Framework

### 2.1 21 CFR Part 11 Controls

| Requirement | Control Implemented |
|-------------|---------------------|
| **Who** — Authenticated user identity | Salesforce Named User Licenses + ClinicalTrialCoordinator Permission Set |
| **What** — Tamper-evident audit trail | Platform Audit Trail + `DigitalSignature` object records per execution |
| **When** — Secure timestamp | `Submission_Timestamp__c` (set by Apex, never editable by users) |
| **Why** — Reason for disqualification | `Disqualification_Reason__c` (mandatory on Ineligible status) + Validation Rule lock |

### 2.2 Record Immutability (GxP Lock)

A Validation Rule (`GxP_Record_Lock`) prevents any field modification on a `ResearchStudyCandidate` once `Eligibility_Status__c` is set to `Submitted`. Any subsequent amendment requires a new candidate record with a documented reason, preserving the original audit record.

### 2.3 Einstein Trust Layer

The Trust Layer is used to:
- Process free-text clinical responses for toxicity screening without retaining data
- Maintain a transparent audit of AI reasoning attached to each `DigitalSignature` record
- Ensure zero data residency for sensitive clinical inputs

---

## 3. Data Model

### 3.1 Design Principle: Standard Objects First

No net-new custom objects are introduced. All clinical data is anchored to standard LSC objects. Custom fields are added only where standard fields are absent.

### 3.2 Object Relationship Diagram

```
PersonAccount (Patient)
    │
    ├──▶ ResearchStudyCandidate  ◀──── ResearchStudy
    │         (Screener Record)              (Protocol)
    │              │
    │              │ [on Eligible]
    │              ▼
    └──▶ CareProgramEnrollee ◀──── CareProgram
              (Enrolled)               (Program)
                   │
                   ▼
           DigitalSignature
           (GxP Audit Record)
```

### 3.3 Standard Objects Used

| Object | Role | Key Standard Fields Used |
|--------|------|--------------------------|
| `PersonAccount` | Patient / Candidate identity anchor | Name, DOB, Gender |
| `ResearchStudy` | Clinical trial protocol | `EligibleMinimumAge`, `EligibleMaximumAge`, `EligibleGender`, `InclusionExclusionCriteria`, `Phase` |
| `ResearchStudyCandidate` | Per-candidate screening record | `CandidateId`, `ResearchStudyId`, `Status`, `MatchedInclusionCritCount`, `MatchedExclusionCritCount`, `IsAutomaticEvaluationCmpl` |
| `CareProgram` | Recruitment & support program | `Status`, `TargetEnrolleeCount`, `CurrentEnrolleeCount` |
| `CareProgramEnrollee` | Official enrollment record | `AccountId`, `CareProgramId`, `ResearchStudyCandidateId`, `Status` |
| `DigitalSignature` | GxP audit trail per execution | `SignatureType` + custom fields |
| `AssessmentEnvelope` | Assessment container | `AccountId`, `Status`, `RequestReferenceId` |

### 3.4 Custom Fields on ResearchStudyCandidate

| API Name | Type | Length | Required | Description |
|----------|------|--------|----------|-------------|
| `Eligibility_Status__c` | Picklist | — | Yes | Screener lifecycle: `In Progress`, `Submitted`, `Eligible`, `Ineligible` |
| `Disqualification_Reason__c` | Long Text Area | 32,768 | Conditional | Mandatory when status = Ineligible. Stores protocol failure narrative. |
| `Protocol_Failure_Code__c` | Text | 255 | No | Machine-readable exclusion criterion code (e.g., `EX-03-AGE`) |
| `Screener_Version__c` | Text | 50 | No | Apex class version that scored this record (e.g., `v1.2.0`) |
| `Submission_Timestamp__c` | DateTime | — | No | System-set timestamp of final submission. Read-only post-submit. |
| `Screener_JSON_Responses__c` | Long Text Area | 131,072 | No | JSON blob of all screener Q&A for audit reconstruction |

---

## 4. Component Inventory

### 4.1 Apex Classes

| Class | Type | Purpose |
|-------|------|---------|
| `ScreenerRequest` | Data Class | Input wrapper passed from Flow to scoring engine |
| `ScreenerResult` | Data Class | Output wrapper returned from scoring engine to Flow |
| `ProtocolEligibilityScoringEngine` | Invocable | Core eligibility evaluation logic; creates audit trail |
| `EligibilityAuditService` | Service | Creates `DigitalSignature` records for GxP traceability |
| `ProtocolEligibilityScoringEngineTest` | Test Class | ≥85% coverage; boundary tests for age-gate, exclusion logic |

### 4.2 Flow

| Name | Type | Trigger |
|------|------|---------|
| `Clinical_Trial_Eligibility_Screener` | Screen Flow | Launched from ResearchStudyCandidate record action |

**Flow Screens:**
1. **Candidate Confirmation** — Display study name, candidate name; confirm intent
2. **Inclusion Criteria Interview** — Dynamic questions from `ResearchStudy.InclusionExclusionCriteria`; age-gate validation
3. **Medical History** — Protocol-specific exclusion questions
4. **Summary & Electronic Signature** — Full response review + LSC Electronic Signature component
5. **Outcome Screen** — Eligible / Ineligible result with next steps

### 4.3 Validation Rule

| Object | Rule Name | Logic |
|--------|-----------|-------|
| `ResearchStudyCandidate` | `GxP_Record_Lock` | Blocks any field edit when `PRIORVALUE(Eligibility_Status__c) = 'Submitted'` |

### 4.4 Permission Set

| Name | Audience | Grants |
|------|----------|--------|
| `ClinicalTrialCoordinator` | Site Coordinators | CRUD on RSC custom fields; Execute Flow; Invoke Apex; Read DigitalSignature |

### 4.5 Flexipage Update

`Research_Study_Candidate_Record_Page` updated to surface:
- `Eligibility_Status__c` in highlights panel
- `Disqualification_Reason__c`, `Protocol_Failure_Code__c` in detail tab
- `Submission_Timestamp__c`, `Screener_Version__c` in audit tab section

---

## 5. Flow Architecture Detail

```
[Launch from Record Action]
         │
         ▼
[Screen 1: Candidate Confirmation]
    - Study Name (from ResearchStudy)
    - Candidate Name (from PersonAccount)
    - Coordinator confirms identity
         │
         ▼
[Screen 2: Inclusion Criteria]
    - Age check (vs EligibleMinimumAge / EligibleMaximumAge)
    - Gender eligibility (vs EligibleGender)
    - Disease indication confirmation
         │
         ▼
[Screen 3: Exclusion / Medical History]
    - Protocol-specific questions (loaded from InclusionExclusionCriteria)
    - Responses captured as JSON string variable
         │
         ▼
[Screen 4: Summary & Signature]
    - Read-only response summary
    - LSC Electronic Signature component
    - Coordinator confirms accuracy
         │
         ▼
[Apex Action: ProtocolEligibilityScoringEngine]
    - Input: CandidateId, StudyId, JSON responses, Coordinator UserId
    - Output: isEligible (Boolean), failureCode (String), reason (String)
         │
    ┌────┴────┐
  [Eligible]  [Ineligible]
     │              │
     ▼              ▼
Create         Update RSC:
CareProgramEnrollee  Eligibility_Status__c = Ineligible
(Status=Active)      Disqualification_Reason__c = reason
     │              Protocol_Failure_Code__c = failureCode
     │              │
     └──────┬───────┘
            ▼
   [Create DigitalSignature Audit Record]
            │
            ▼
   [Screen 5: Outcome Display]
```

---

## 6. Apex Scoring Engine Logic

### 6.1 Method Signature

```apex
@InvocableMethod(label='Score Protocol Eligibility' category='Clinical Trials')
public static List<ScreenerResult> scoreEligibility(List<ScreenerRequest> requests)
```

### 6.2 Evaluation Sequence

1. **Bulkification** — Process all requests in a single loop (no SOQL inside loops)
2. **Load Protocol** — Query `ResearchStudy` for age bounds, gender, criteria text
3. **Age Gate** — Compare candidate DOB vs `EligibleMinimumAge`/`EligibleMaximumAge`; fail code `EX-01-AGE`
4. **Gender Gate** — Compare candidate gender vs `EligibleGender`; fail code `EX-02-GENDER`
5. **Exclusion Criteria** — Parse JSON responses; evaluate against protocol flags; fail codes `EX-03-*`
6. **Inclusion Criteria** — Verify mandatory positive responses; fail code `IN-01-*`
7. **Score & Return** — Populate `ScreenerResult`; trigger `EligibilityAuditService`
8. **DML** — Update `ResearchStudyCandidate`, create `CareProgramEnrollee` (if eligible)

### 6.3 GxP Audit Record

For every invocation, `EligibilityAuditService` creates a `DigitalSignature` record capturing:
- `SignatureType` = `System`
- Related RSC Id
- Input JSON (truncated to 32KB)
- Apex class version
- Outcome code
- Running user + timestamp

---

## 7. Validation Strategy (SMART / GxP)

| Phase | Objective | Test Cases |
|-------|-----------|-----------|
| **IQ** — Installation Qualification | Confirm metadata deployed | Apex coverage ≥85%; fields present; validation rule active |
| **OQ** — Operational Qualification | Confirm logic functions | Age boundary (17 → fail, 18 → pass, 65 → pass, 66 → fail); gender mismatch; exclusion criterion triggered |
| **PQ** — Performance Qualification | Confirm real-world use | UAT with coordinators on mobile; full screener end-to-end on scratch org |

### 7.1 Boundary Test Matrix

| Test | Input | Expected Outcome |
|------|-------|-----------------|
| Age below minimum | DOB = today - 17 years | Ineligible, code `EX-01-AGE` |
| Age at minimum | DOB = today - 18 years | Eligible (age gate passes) |
| Age at maximum | DOB = today - 65 years | Eligible (age gate passes) |
| Age above maximum | DOB = today - 66 years | Ineligible, code `EX-01-AGE` |
| Gender mismatch | Female candidate, Male-only study | Ineligible, code `EX-02-GENDER` |
| Exclusion criterion met | Prior cancer history on oncology exclusion | Ineligible, code `EX-03-HIST` |
| All criteria pass | Valid age, gender, no exclusions | Eligible → CareProgramEnrollee created |
| Record lock attempt | Edit after Submitted | Validation Rule blocks, error shown |

---

## 8. Audit Readiness Documents (To Maintain)

| Document | Owner | Frequency |
|----------|-------|-----------|
| Validation Summary Report (VSR) | QA Lead | Per Salesforce release |
| Traceability Matrix | Implementation Lead | Per protocol change |
| Risk Assessment | QA + IT Security | Annual + per change |
| SOP: System Access & Security | IT Security | Annual review |
| SOP: Audit Trail Review | QA Lead | Quarterly inspection |

---

## 9. Deployment Order

1. Custom fields on `ResearchStudyCandidate`
2. Validation Rule (`GxP_Record_Lock`)
3. Apex classes (`ScreenerRequest`, `ScreenerResult`, `EligibilityAuditService`, `ProtocolEligibilityScoringEngine`)
4. Apex test class (`ProtocolEligibilityScoringEngineTest`) — run and confirm ≥85%
5. Flow (`Clinical_Trial_Eligibility_Screener`)
6. Permission Set (`ClinicalTrialCoordinator`)
7. Flexipage update (`Research_Study_Candidate_Record_Page`)
8. Package.xml update

---

*End of Solution Design Document*
