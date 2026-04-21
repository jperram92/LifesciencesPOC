# Codex OmniStudio Setup For Account Summary

This workspace is configured for Codex to use two MCP servers:

- `Salesforce DX`: metadata retrieval and deployment against org alias `LifesciencesPOC`
- `omnistudio-mcp`: OmniStudio authoring for Data Mapper and FlexCard generation

The local MCP config is in [`.mcp.json`](/mnt/c/Users/james/LifeSciencesPOC/LifesciencesPOC/.mcp.json:1). VS Code uses [`.vscode/mcp.json`](/mnt/c/Users/james/LifeSciencesPOC/LifesciencesPOC/.vscode/mcp.json:1).

## Authentication

Do not store `SF_ACCESS_TOKEN` or `SF_INSTANCE_URL` in the repo. Export them from the authenticated Salesforce CLI org before starting Codex or any MCP client that needs OmniStudio authoring.

From bash:

```bash
eval "$(./scripts/setup-omnistudio-mcp-env.sh LifesciencesPOC)"
```

That script reads the current Salesforce CLI auth for the org alias and exports:

- `SF_INSTANCE_URL`
- `SF_ACCESS_TOKEN`
- `SF_ORG_ALIAS`

## Source Record

The seed data script is [CreateAccountSummaryTestData.apex](/mnt/c/Users/james/LifeSciencesPOC/LifesciencesPOC/scripts/apex/CreateAccountSummaryTestData.apex:1).

It creates an `Account` record with these fields:

- `Name`
- `Phone`
- `Industry`
- `Type`
- `BillingStreet`
- `BillingCity`
- `BillingState`
- `BillingPostalCode`
- `BillingCountry`
- `Website`

## Target OmniStudio Assets

Use Codex with Salesforce MCP and OmniStudio MCP to create:

1. DataRaptor Extract `AccountSummaryGetDetails`
2. FlexCard `AccountSummary_Salesforce_1`

### DataRaptor contract

- Type: Extract
- Input: `AccountId`
- Primary object: `Account`
- Filter: `Account.Id = AccountId`
- Output JSON shape:

```json
{
  "AccountId": "001...",
  "Account": {
    "Name": "",
    "Phone": "",
    "Industry": "",
    "Type": "",
    "BillingStreet": "",
    "BillingCity": "",
    "BillingState": "",
    "BillingPostalCode": "",
    "BillingCountry": "",
    "Website": ""
  }
}
```

### FlexCard contract

- Theme: Salesforce SLDS
- Context input: `recordId`
- Data source: `AccountSummaryGetDetails`
- Input map: `AccountId = {recordId}`
- Display fields:
  - Name
  - Phone
  - Industry
  - Type
  - Billing address as a readable block
  - Website

## Suggested Codex Prompt

```text
Use the Salesforce DX MCP and omnistudio-mcp servers in this workspace.

1. Run scripts/apex/CreateAccountSummaryTestData.apex against org alias LifesciencesPOC and capture the created Account Id.
2. Create a DataRaptor Extract named AccountSummaryGetDetails that accepts AccountId and returns Name, Phone, Industry, Type, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, and Website for that Account.
3. Create a FlexCard named AccountSummary_Salesforce_1 that takes recordId, calls AccountSummaryGetDetails with AccountId={recordId}, and renders those fields in a compact account-summary layout.
4. Retrieve the generated OmniStudio metadata into force-app/main/default/omniDataTransforms and force-app/main/default/omniUiCard.
5. Summarize the created metadata files and any deployment steps still required.
```

## Notes

- If Codex is already running, restart it after exporting the environment variables so the `omnistudio-mcp` server inherits them.
- If you want this configuration available for every repository, add the same servers to `~/.codex/config.toml`. That change is global and separate from this repo-local setup.
