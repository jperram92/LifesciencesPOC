---
name: sf-omniscript
description: >
Comprehensive guide for creating and maintaining OmniStudio OmniScripts (.os-meta.xml files).
TRIGGER when: user creates new OmniScript versions, edits .os-meta.xml files, fixes Designer UI
crashes, adds steps/elements to an OmniScript, deploys/retrieves OmniScripts, or works with
the omniScripts/ folder.
DO NOT TRIGGER when: OmniStudio DataRaptors/Integration Procedures (use sf-metadata), LWC OmniOut
components (use sf-lwc), or Apex invoked from OmniScript (use sf-apex).
license: MIT
metadata:
version: "1.3.0"
author: "HLS Assets Team"
sf-omniscript
This skill ensures that all OmniStudio OmniScript components created or modified in this repository are syntactically complete, UI-compatible, and consistently named.
1. Directory Structure
Flat Folder Structure (Recommended):
All OmniScript files should reside in the root of the `omniScripts/` directory.
Path: `force-app/main/default/omniScripts/<filename>.os-meta.xml`
Legacy Subfolder Structure:
Avoid using subfolders (e.g., `omniScripts/HLS_ReferralForm_English/`) unless explicitly requested for legacy migration purposes. If a retrieval results in a flat file, keep it flat.
2. Naming Convention
Filename & UniqueName:
Pattern: `HLS_<SubType>_<Language>_<Version>.os-meta.xml`
Example: `HLS_ReferralForm_English_7.os-meta.xml`
UniqueName: `HLS_<SubType>_<Language>_<Version>`
Rules:
Use the `HLS` prefix followed by an underscore `_`.
The `UniqueName` tag in the XML MUST exactly match the filename (without extension).
If the `Type` is `HLS`, ensure the underscore separates it from the `SubType`.
3. Mandatory Metadata Tags
The OmniStudio Designer UI requires specific tags to correctly map the element tree. Missing these tags causes errors in the UI even if the form works on the frontend.
Every element (including children) MUST have:
`<omniProcessVersionNumber>0.0</omniProcessVersionNumber>`
`<isActive>true</isActive>`
`<level>` (0.0 for steps/actions, 1.0 for children, etc.)
Root-Level Designer Compatibility:
The root `<OmniScript>` element should include:
`<isManagedUsingStdDesigner>false</isManagedUsingStdDesigner>`
`<elementTypeComponentMapping>{&quot;ElementTypeToHTMLTemplateList&quot;:[]}</elementTypeComponentMapping>`
`<isOmniScriptEmbeddable>true</isOmniScriptEmbeddable>` (usually true for web components)
Child-Level Requirements:
Every `childElements` block MUST have `<isOmniScriptEmbeddable>false</isOmniScriptEmbeddable>`.
4. `propertySetConfig` Accuracy
The `propertySetConfig` JSON block MUST contain a minimum set of keys to be recognized by the Designer UI.
Step/Action Minimum Keys:
```json
{
  "label": "My Step",
  "validationRequired": true,
  "previousLabel": "Back",
  "previousWidth": 3,
  "nextLabel": "Continue",
  "nextWidth": 3,
  "cancelLabel": "Cancel",
  "cancelMessage": "Are you sure?",
  "saveLabel": "Save for later",
  "saveMessage": "Are you sure you want to save it for later?",
  "completeLabel": "Complete",
  "completeMessage": "Are you sure you want to complete the script?",
  "instruction": "",
  "showPersistentComponent": [ true, false ],
  "remoteClass": "",
  "remoteMethod": "",
  "remoteTimeout": 30000,
  "remoteOptions": { },
  "knowledgeOptions": {
    "language": "English",
    "publishStatus": "Online",
    "keyword": "",
    "dataCategoryCriteria": "",
    "remoteTimeout": 30000,
    "typeFilter": ""
  },
  "show": null,
  "conditionType": "Hide if False",
  "HTMLTemplateId": "",
  "instructionKey": "",
  "chartLabel": "About",
  "allowSaveForLater": false,
  "errorMessage": {
    "custom": [ ],
    "default": null
  },
  "wpm": false,
  "ssm": false,
  "message": { },
  "pubsub": false,
  "businessCategory": "",
  "businessEvent": ""
}
```
Input Element (Child) Minimum Keys:
```json
{
  "controlWidth": 12,
  "label": "My Input",
  "required": false,
  "show": null,
  "conditionType": "Hide if False",
  "HTMLTemplateId": "",
  "hide": false,
  "disOnTplt": false
}
```
Select Element (Picklist) Full `propertySetConfig`:
A `Select` element requires more keys than a plain `Text` input. Missing `optionSource`, `conditionType`, `HTMLTemplateId`, `hide`, or `disOnTplt` will cause Designer errors.
```json
{
  "label": "My Picklist",
  "controlWidth": 4,
  "required": false,
  "repeat": false,
  "repeatClone": false,
  "repeatLimit": null,
  "readOnly": false,
  "help": false,
  "helpText": "",
  "options": [
    { "name": "", "value": "" },
    { "name": "Option A", "value": "Option A" },
    { "name": "Option B", "value": "Option B" }
  ],
  "optionSource": {
    "type": "",
    "source": ""
  },
  "show": null,
  "conditionType": "Hide if False",
  "HTMLTemplateId": "",
  "hide": false,
  "disOnTplt": false
}
```
Select element rules:
`name` = API value (CRITICAL for Salesforce field mapping): When a `Select` element maps to a Salesforce picklist field (e.g., `Lead.Salutation`), set `options[*].name` to the exact Salesforce API value (e.g., `"Mr."`, not `"Mister"`). The `name` key is what gets stored in the OmniScript state and read by downstream DataRaptors — if it matches the API value, no formula translation is needed anywhere in the pipeline.
`name` vs `value`: `name` is the stored/API value; `value` is the display label. For standard Salesforce picklists they are identical. For custom labels (e.g., display `"Doctor"` but store `"Dr."`) use different values.
Blank/unselected option: Use `{"name": "", "value": ""}` as the first option for optional fields. Do not set a `defaultValue` key — the blank option acts as the unselected state.
Select vs Radio: Use `Radio` for ≤3 mutually exclusive options that benefit from always-visible display. Use `Select` for ≥4 options, or when column width constrains layout (e.g., `controlWidth: 4`).
Clone strategy: Always base the `Select` block on an existing option-bearing element in the same file (e.g., a `Radio` element). Copy the full XML block and replace `type`, `options`, and label — never synthesise `propertySetConfig` keys from memory.
5. Deployment & Retrieval
Retrieve: `sf project retrieve start -m OmniScript:UniqueName -o org-alias`
Deploy: `sf project deploy start -m OmniScript:UniqueName -o org-alias`
After retrieval, ensure the file is in the flat `omniScripts/` folder and that the `<uniqueName>` tag matches the filename.
6. Designer Crash "Gotchas" & Troubleshooting
When modifying `.os-meta.xml` files manually, strict adherence to OmniStudio engine expectations is required. Failure to do so will result in unhandled exceptions in the Designer UI (e.g., `Failed to execute 'removeChild' on 'Node'` or `Cannot read properties of undefined (reading 'publishStatus')`).
Gotcha 1: Physical XML Ordering vs. Logical Sequence
Issue: The OmniStudio Designer relies heavily on the physical order of the `<omniProcessElements>` tags matching their logical `sequenceNumber`.
Fix: ALWAYS ensure elements are physically ordered in the XML (e.g., Sequence 1.0, then 2.0, then 3.0). Never append a new step to the end of the file if its logical sequence belongs earlier.
Gotcha 2: Missing "Hidden" Mandatory Properties
Issue: The Designer UI expects specific properties like `knowledgeOptions` and `errorMessage` to exist within `propertySetConfig`, even if they are empty or unused.
Fix: ALWAYS use a "Clone" strategy. Grep for an existing, working element of the exact same type in the file, copy its entire XML block, and modify it. Do not attempt to synthesize `propertySetConfig` JSON from memory.
Gotcha 3: Formula Evaluation Prefix (`=`)
Issue: OmniScript engines treat strings as literals unless explicitly told otherwise.
Fix: In `Set Values` or `Set Errors` element maps, ALWAYS prepend an equals sign (`=`) to ensure the string is evaluated as a formula (e.g., `=IF(%HasNoFunding% == true, false, %HasMyAgedCare%)`).
Gotcha 4: Context-Relative JSON Pathing
Issue: When using `Set Errors` logic at Level 0.0 (between steps), absolute JSON paths (e.g., `StepName:FieldName`) in `show` conditions can fail to trigger correctly depending on the engine context.
Fix: Use relative field names (e.g., `HasNoFunding`) instead of absolute paths (e.g., `FundingDetails:HasNoFunding`) in the validation conditions if the absolute path fails to trigger.
Gotcha 5: Data Transformation vs. Validation Paradigm
Issue: Using `Set Values` to silently mutate data mid-flight to enforce UI logic (like mutual exclusivity) is an anti-pattern and often leads to circular dependencies or erratic behavior.
Fix: Shift left on validation. Use Set Errors elements to block the user and force them to correct conflicting input rather than silently fixing it for them.
Gotcha 6: Silent Field Drop at the DataRaptor Load Boundary
Issue: A DataRaptor Transform can map an OmniScript field to a JSON output key, but if the downstream DataRaptor Load does not have a corresponding `omniDataTransformItem` consuming that key, the field is silently discarded — the SObject is created without it, with no error or debug log noise. This is invisible at runtime: the form submits, the record is created, but the field is always blank.
Example: `HLSDTReferralFormLead` mapped `AboutYou:IntakeSalutation` → `ClientSalutation` (JSON), but `HLSDTCreateLead` had no `ClientSalutation → Lead.Salutation` item. `Lead.Salutation` was always null with zero indication of the gap.
Fix: When auditing or extending a data pipeline, always cross-check Transform `outputFieldName` values against Load `inputFieldName` values. A field present in the Transform output but absent from the Load input is silent data loss. Use `grep` across both `.rpt-meta.xml` files to verify symmetry:
```bash
  grep "outputFieldName" omniDataTransforms/HLSDTTransform_1.rpt-meta.xml
  grep "inputFieldName"  omniDataTransforms/HLSDTLoad_1.rpt-meta.xml
  ```
Every output field in the Transform that should reach the SObject must have a matching input entry in the Load.
Gotcha 7: Empty String vs Null Through `nullInputsIncludedInOutput: false`
Issue: Both Transform and Load DataRaptors commonly have `nullInputsIncludedInOutput: false`. This setting suppresses `null` values but passes through empty strings (`""`) unchanged. For optional `Select` elements with a blank first option (`{"name": "", "value": ""}`), the stored OmniScript state value is `""` (empty string, not null) — this flows through both DRs and reaches the SObject write. Salesforce treats `""` as null for picklist fields (no error, field left blank). The behaviour is correct but non-obvious and should be verified explicitly.
Fix: When adding an optional `Select` element that maps to a Salesforce picklist field, confirm the blank option stores `""` (not a sentinel like `"none"`) and that neither DR is configured to block empty strings. Test by submitting the form without selecting a value and inspecting the created record — `Lead.Salutation` (or equivalent) should be blank.
7. Show Conditions (`show` property)
This is the most error-prone area when authoring OmniScript XML manually.
7.1 Field Path Syntax — BARE names only (CRITICAL)
The `field` key inside a `show` condition rule ALWAYS uses the bare element name, regardless of which step the field belongs to.
```json
// CORRECT — bare field name
"show": {
  "group": {
    "operator": "AND",
    "rules": [{ "condition": "=", "field": "Nursing", "data": "true" }]
  }
}

// WRONG — do NOT prefix with step name
"show": {
  "group": {
    "operator": "AND",
    "rules": [{ "condition": "=", "field": "CareNeeds:Nursing", "data": "true" }]
  }
}
```
Why: OmniScript maintains a single flat JSON state object at runtime. All field values from all steps are stored at the root level (e.g., `{ "Nursing": true, "IntakeFirstName": "John" }`). The show condition evaluator reads directly from this flat map — there is no step namespace.
> **Before writing any show condition, read the existing `show` conditions already in the same `.os-meta.xml` file.** Those are ground-truth examples of the correct field path format for that script. Do not rely on documentation or subagent guidance over live file evidence.
7.2 Condition Operators
Use only these operators — they are what the OmniStudio Designer serialises:
Operator	Meaning	When to use
`=`	Equal	Field equals a specific value
`<>`	Not equal	Field is not a specific value
`>`	Greater than	Numeric comparisons
`<`	Less than	Numeric comparisons
`>=`	Greater or equal	Numeric comparisons
`<=`	Less or equal	Numeric comparisons
`!=` is NOT a valid OmniScript operator. Using `!=` causes the condition to silently fail (evaluates as always-false with `Hide if False`, so the element becomes permanently hidden or permanently visible depending on `conditionType`).
7.3 Three Distinct Path Conventions (Do Not Mix)
OmniScript uses three different path syntaxes depending on context. They are NOT interchangeable:
Context	Correct syntax	Example
`show` condition `field` key	Bare element name	`"field": "Nursing"`
Text Block `text` merge fields	`%StepName:FieldName%`	`%CareNeeds:Nursing%`
Integration Procedure JSON input	Dot-notation nested path	`CareNeeds.Nursing`
A common mistake is applying merge field colon-notation (`StepName:FieldName`) to `show` condition `field` keys — these are evaluated by completely different runtime mechanisms.
7.4 Disabling `show` Condition (Always Visible)
Use `"show": null` (not an empty object `{}`) when an element should always be visible:
```json
"show": null
```
8. Text Block Elements
Text Blocks are the correct element type for displaying read-only data (e.g., review/confirmation steps).
8.1 Merge Fields in Text Content
Use `%StepName:FieldName%` syntax inside the `text` HTML string to display values from previous steps:
```json
"text": "<p>First Name</p><div>%AboutYou:IntakeFirstName%</div>"
```
Note: The colon-prefixed step name (`StepName:FieldName`) IS correct here — this is the merge field resolution layer, which is separate from the show condition evaluator.
8.2 `sanitize` Property
Use `"sanitize": false` when the `text` content is developer-controlled HTML with merge fields. This is consistent with how the OmniStudio Designer serialises Text Block content by default.
`"sanitize": true` runs content through DOMPurify, which can strip `<div>` and other structural tags from the rendered output depending on org configuration.
Default to `"sanitize": false` for review/display Text Blocks. Only use `true` if the content contains user-supplied input that needs XSS protection.
8.3 Minimum `propertySetConfig` for a Text Block
```json
{
  "label": "MyTextBlock",
  "text": "<p>Your content here</p>",
  "sanitize": false,
  "dataJSON": false,
  "textKey": "",
  "controlWidth": 12,
  "show": null,
  "conditionType": "Hide if False",
  "HTMLTemplateId": "",
  "hide": false,
  "disOnTplt": false
}
```
9. Review / Confirmation Steps
When adding a review step that mirrors form data back to the user:
9.1 Section ordering
Order the review sections to match the step progression of the form (e.g., if the form goes About You → Contact → Needs → Funding, the review step should mirror that order). Do not reorder for convenience during authoring.
9.2 Visual spacers
Insert `Line Break` elements between logical sections. The Designer uses `"padding": 24` as the default:
```xml
<childElements>
    <isActive>true</isActive>
    <isOmniScriptEmbeddable>false</isOmniScriptEmbeddable>
    <level>1.0</level>
    <name>LineBreakN</name>
    <omniProcessVersionNumber>0.0</omniProcessVersionNumber>
    <propertySetConfig>{
  &quot;label&quot; : &quot;LineBreakN&quot;,
  &quot;padding&quot; : 24,
  &quot;show&quot; : null,
  &quot;HTMLTemplateId&quot; : &quot;&quot;
}</propertySetConfig>
    <sequenceNumber>N.0</sequenceNumber>
    <type>Line Break</type>
</childElements>
```
9.3 Conditional display patterns
Scenario	Condition operator	`data` value
Checkbox was ticked	`=`	`"true"`
Optional text field was filled	`<>`	`""` (empty string)
"None selected" fallback (all checkboxes unchecked)	All rules use `<>`	`"true"`
9.4 Next button label
For a review step that submits the form, update `nextLabel` to `"Submit"` in the step's `propertySetConfig`. The default "Continue" is misleading on a terminal step.
10. Pre-deploy Checklist for XML Authored OmniScripts
Before deploying any manually edited `.os-meta.xml`, verify:
[ ] All `show` condition `field` values use bare field names (no `StepName:` prefix)
[ ] All "not equal" conditions use `<>` (not `!=`)
[ ] Cross-referenced the existing `show` conditions in the same file to confirm field name format
[ ] `sequenceNumber` values are unique and correctly ordered within each parent element group
[ ] New steps do not reuse sequence numbers already assigned to other elements
[ ] Text Blocks that display merge-resolved HTML use `"sanitize": false`
[ ] Review sections are ordered to match the form's step progression
[ ] Deploy as `isActive: false` first; activate only after Designer preview verification
[ ] Select elements: `options[*].name` values match the target Salesforce picklist API values exactly
[ ] Select elements: blank first option `{"name": "", "value": ""}` present for optional fields
[ ] Select elements: all required `propertySetConfig` keys present (`optionSource`, `conditionType`, `HTMLTemplateId`, `hide`, `disOnTplt`)
[ ] Pipeline audit (if any field added/changed): cross-check Transform `outputFieldName` vs Load `inputFieldName` — every field that should reach the SObject must appear in both (see Gotcha 6)
[ ] Element naming: OmniScript `<name>` values do NOT carry `HLS_` prefix — bare descriptive names only (see Section 13)
[ ] DR Transform `inputFieldName`: all form-field inputs use `StepName:FieldName` path, not flat key (see Section 12)
[ ] Conditional element budget: count existing conditional elements before adding new ones; total must not exceed 20 (see Section 14)
[ ] DR formulas: no `CONCATENATE()` — use `&` operator for string concatenation; tested in DR Designer before committing XML (see Section 15)
11. DataRaptor Pipeline Audit (When Adding or Changing Fields)
Whenever an OmniScript element is added, renamed, or its stored value changes type, audit the full pipeline:
11.1 Pipeline stages
```
OmniScript element (name key stored in state)
    ↓  [DR Transform: inputFieldName = StepName:ElementName]
Transform JSON output (outputFieldName)
    ↓  [DR Load: inputFieldName = Transform outputFieldName]
SObject field (outputFieldName = API field name, outputObjectName = SObject)
```
11.2 Audit steps
Identify the element name and step in the OmniScript (e.g., `AboutYou:IntakeSalutation`).
Find the Transform DR — grep for the element name in `inputFieldName`:
```bash
   grep -r "IntakeSalutation" force-app/main/default/omniDataTransforms/
   ```
Note the Transform's `outputFieldName` (e.g., `ClientSalutation`) — this is the JSON key passed to the Load.
Find the Load DR — grep for the Transform output field name in `inputFieldName`:
```bash
   grep "ClientSalutation" force-app/main/default/omniDataTransforms/HLSDTLoad_1.rpt-meta.xml
   ```
If absent → silent data loss. Add the mapping item to the Load DR (see Gotcha 6).
Note the Load's `outputFieldName` — confirm it matches the SObject API field name exactly.
11.3 Deployment order
Always deploy DataRaptor components before the OmniScript that calls them:
```bash
# 1. Transform DR (if changed)
sf project deploy start -m OmniDataTransform:HLSDTTransform_1 -o <org>
# 2. Load DR (if changed)
sf project deploy start -m OmniDataTransform:HLSDTLoad_1 -o <org>
# 3. OmniScript (last)
sf project deploy start -m OmniScript:HLS_MyScript_English_9 -o <org>
```
Deploying the OmniScript before its dependent DataRaptors creates a window where submitted forms silently drop fields.
---
12. DataRaptor Transform — Step-Scoped Input Path (CRITICAL)
> **This is the most common source of silent data loss when extending an existing pipeline.**
12.1 How the DR Transform reads OmniScript state
The DataRaptor Transform receives the entire OmniScript state JSON as its primary input. This is the same nested JSON object visible in the debug panel when running the script in preview mode:
```json
{
  "AboutYou":      { "IntakeFirstName": "Jane", "IntakeFamilyName": "Smith" },
  "ContactingYou": { "IntakeEmailAddress": "jane@example.com", "StreetAddress1": "42 Elm St" },
  "CareNeeds":     { "Nursing": true, "AlliedHealth": false }
}
```
The `inputFieldName` in each `omniDataTransformItem` uses colon-separated step path notation to navigate this structure:
```
CareNeeds:Nursing              →  reads state.CareNeeds.Nursing
AboutYou:IntakeFirstName       →  reads state.AboutYou.IntakeFirstName
ContactingYou:StreetAddress1   →  reads state.ContactingYou.StreetAddress1
```
12.2 The golden rule — always use StepName:FieldName for OmniScript form fields
Before adding any new DR Transform item, read the existing `inputFieldName` entries in the same `.rpt-meta.xml` file. They show the exact path format used for that script. New fields from the same step follow the same pattern exactly.
```xml
<!-- CORRECT — reads directly from OmniScript state -->
<inputFieldName>ContactingYou:StreetAddress1</inputFieldName>
<inputFieldName>ContactingYou:City</inputFieldName>
<inputFieldName>CareNeeds:Nursing</inputFieldName>

<!-- WRONG — flat key only works if the IP explicitly injects it via additionalInput -->
<inputFieldName>StreetAddress1</inputFieldName>
<inputFieldName>City</inputFieldName>
```
12.3 Flat keys vs. nested step paths — they are NOT interchangeable
The DR Transform input JSON has two types of keys:
Source	Key format in DR input	When to use `inputFieldName`
OmniScript state (form fields)	Nested: `ContactingYou.City`	`ContactingYou:City`
IP `additionalInput`	Flat top-level: `RecordTypeId`	`RecordTypeId`
If you use `inputFieldName: City` (flat) but the data lives at `state.ContactingYou.City` (nested), the DR finds nothing at the root-level key `City` and the field is silently dropped — `nullInputsIncludedInOutput: false` discards it with zero error output.
12.4 When is IP `additionalInput` appropriate?
Use the IP `Set Values` + `additionalInput` route only for values that require conditional logic or are computed/derived at the IP level (e.g., picking between self-referral and third-party names, resolving a RecordTypeId). Raw form fields that come straight from OmniScript input do not need to pass through the IP — the DR Transform reads them directly.
```
Rule: Raw OmniScript form field  →  StepName:FieldName  (DR reads direct from state)
Rule: IP-computed or conditional  →  flat additionalInput key  (IP injects, DR reads flat)
```
12.5 Gotcha 8 — Flat additionalInput key silently shadows missing nested field
Issue: If the IP passes `City` as a flat `additionalInput` key but the DR Transform item uses `inputFieldName: ContactingYou:City` (nested), these are independent. Neither errors. The DR simply reads the nested path and ignores the flat key. If the nested path also has no value (because you forgot to add it to the OmniScript), the field is silently null.
Failure mode: Form submits successfully. Lead/SObject is created. The field is permanently blank. No debug log entry.
Fix: Always verify the path type matches the data source. Retrieve the org version and grep `inputFieldName` values if unsure.
---
13. OmniScript Element Naming — Scope of `HLS_` Prefix
13.1 Where `HLS_` applies
The `HLS_` prefix convention applies to Salesforce metadata API names — things stored in the org metadata schema:
Custom fields: `HLS_Date_of_Birth__c`
Custom objects: `HLS_Referral__c`
Permission sets, flows, queues, validation rules, etc.
13.2 Where `HLS_` does NOT apply
OmniScript element `<name>` values are JavaScript object keys in a runtime JSON state. They are never persisted as Salesforce metadata API names and must not carry the `HLS_` prefix.
```xml
<!-- CORRECT — plain descriptive name, no prefix -->
<name>StreetAddress1</name>
<name>City</name>
<name>Postcode</name>

<!-- WRONG — HLS_ prefix is for Salesforce metadata API names, not OS data nodes -->
<name>HLS_StreetAddress1</name>
<name>HLS_City</name>
```
The only OmniScript elements that warrant a prefix are UI display elements (headings, spacers) that have no downstream data meaning and benefit from a namespace to avoid clashing with field names:
```xml
<!-- OK — heading has no data meaning, prefix avoids name collision -->
<name>HLS_AddressHeading</name>
```
13.3 Impact of wrong names
If an OmniScript element is named `HLS_City`, the state JSON stores `{ "HLS_City": "Sydney" }`. Every downstream reference must then use `HLS_City` — the DR Transform `inputFieldName`, the IP `%ContactingYou:HLS_City%` reference, and any merge fields in Text Blocks. A single rename ripples through all layers. Name elements correctly from the start.
---
14. Conditional Element Budget (Designer Limit: 20)
14.1 The limit
The OmniStudio Designer enforces a maximum of 20 conditional elements per OmniScript. An element is "conditional" when its `show` property is not `null` — i.e., it has a `show.group.rules` block. Exceeding this limit triggers a Design Assistant warning that blocks activation.
14.2 Count before adding
Before adding any new conditionally-shown elements:
Run a grep to count existing conditional elements in the file:
```bash
   grep -c '"condition"' force-app/main/default/omniScripts/MyScript.os-meta.xml
   ```
If you are close to 20, consolidate — see 14.3.
14.3 Consolidation pattern for review sections
Instead of one conditional Text Block per field (N conditional elements), use one conditional Text Block per section that renders all fields together:
```json
{
  "text": "<p>Address</p><div>%ContactingYou:StreetAddress1%</div><div>%ContactingYou:StreetAddress2%</div><div>%ContactingYou:City% %ContactingYou:Postcode%</div><div>%ContactingYou:State% %ContactingYou:Country%</div>",
  "show": {
    "group": {
      "operator": "AND",
      "rules": [{ "condition": "<>", "field": "StreetAddress1", "data": "" }]
    }
  }
}
```
This pattern:
Uses 1 conditional element for an entire address section (not 6)
Shows the whole section when the primary anchor field (e.g., `StreetAddress1`) is non-empty
Empty merge fields render as blank strings — no separate hide logic needed per sub-field
14.4 Gotcha 9 — One conditional element per field is an anti-pattern
Issue: Adding 6 individual conditional review Text Blocks for 6 address sub-fields consumes 6 of the 20-element budget in one change.
Failure mode: Designer warns "The number of Conditional OmniScript Elements can't exceed 20." Activation is blocked.
Fix: Default to one conditional block per logical section (e.g., the whole address group), not per field. Reserve individual field conditions only for fields that have genuinely independent visibility logic (e.g., `Street address 2` shown only when `StreetAddress2` is non-empty within an otherwise unconditional address section).
---
15. DataRaptor Formula Engine — Supported Functions
15.1 What IS supported
The DataRaptor Transform formula engine supports a limited expression set. Verified working:
Function / Operator	Example
`IF(condition, true, false)`	`IF(ISBLANK(RecordTypeId), "default", RecordTypeId)`
`ISBLANK(field)`	`ISBLANK(StreetAddress2)`
`AND`, `OR`, `NOT`	`AND(ISBLANK(x), ISBLANK(y))`
`==`, `<>`, `>`, `<`, `>=`, `<=`	`ReferralOption == "myself"`
`&` for string concatenation	`StreetAddress1 & " " & StreetAddress2`
`+`, `-`, `*`, `/` for numeric	`TotalAmount + GSTAmount`
15.2 What is NOT supported
Function	Error	Alternative
`CONCATENATE(a, b, c)`	`CONCATENATE is not a Function or Operator`	Use `&` operator: `a & " " & b`
Apex String methods	Runtime error	Use DR formula operators
Multi-argument `CONCATENATE`	Not recognised	Chain `&`: `a & b & c`
15.3 String concatenation — operator reference
Salesforce formula language uses `&` for strings across all layers. Using `+` for strings is a silent failure in most contexts (it may return `0` or null):
Layer	String concat operator	Numeric operator
DataRaptor formula	`&`	`+`
IP Set Values formula	`&`	`+`
Salesforce formula fields	`&`	`+`
Apex	`+`	`+` (same)
> **Never use `+` to concatenate strings in any Salesforce formula context outside Apex.**
15.4 Gotcha 10 — Formula function assumed but unsupported silently drops the field
Issue: Using an unsupported formula function (e.g., `CONCATENATE`) does not throw a deploy error. The formula item is deployed successfully. At runtime the formula evaluation fails, the `formulaResultPath` variable is never set, and any downstream pass-through item that reads it gets null. With `nullInputsIncludedInOutput: false`, the field is silently dropped.
Failure mode: Form submits. Record is created. The formula-derived field is always null.
Fix: Always test a new DataRaptor formula in the Designer's Formula Builder or Preview tab before committing it to XML. The Designer will show a parse error immediately if the function is unsupported.
15.5 `expectedInputJson` — Designer diagnostic field
When using the DR Transform Designer's preview/test feature, the Designer saves the last test payload as `<expectedInputJson>` in the `.rpt-meta.xml` file upon retrieval. This field is non-functional metadata — it has no effect on DR execution. It is safe to commit as-is; it serves as a useful snapshot of the actual runtime input shape for future debugging.