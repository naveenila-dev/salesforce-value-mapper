# Salesforce Value Mapper

Versioned value mappings, explicit override rules, and an explanation for every result.

A reusable Apex library for exact string-to-string translation using `Value_Mapping__mdt`. Install the source into your own Salesforce org, then define your own providers, mapping types, versions, and values. It has no customer data model, external service, or org-specific dependency. Licensed under [MIT](LICENSE).

## Install in your org

You need Git, the [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli), and an org with Apex and Custom Metadata support on **API 65.0 or later**. Your user must be allowed to deploy Apex and Custom Metadata and execute anonymous Apex for the smoke check. Start in a sandbox or Developer Edition org. No Dev Hub, npm install, package ID, or paid service is required for source installation.

Clone this repository:

```sh
git clone https://github.com/naveenila-dev/salesforce-value-mapper.git
cd salesforce-value-mapper
```

Authorize **your own target org**, choosing one login command:

```sh
# Sandbox
sf org login web --alias value-mapper --instance-url https://test.salesforce.com

# Developer Edition or production
sf org login web --alias value-mapper --instance-url https://login.salesforce.com
```

You may use your org's My Domain login URL instead. `value-mapper` is a local alias you choose, not a preconfigured org. Use the same alias in the commands below.

Validate, then install (macOS/Linux Bash or Git Bash on Windows):

```sh
bash scripts/install.sh --target-org value-mapper --dry-run
bash scripts/install.sh --target-org value-mapper
```

The installer deploys only the library, Custom Metadata Type, and tests. **No mapping records are installed by default.** It explicitly targets the org you supply, runs `MappingResolverTest` and `MappingFlowActionTest`, and runs a smoke check after a successful deployment. It stops on deployment errors, pending deployments, and smoke failures. The dry run saves no changes and skips the smoke check.

Without Bash, run the equivalent commands from the repository root (also usable in PowerShell):

```sh
sf project deploy start --source-dir force-app --target-org value-mapper --test-level RunSpecifiedTests --tests MappingResolverTest --tests MappingFlowActionTest --wait 30
sf apex run --file scripts/apex/value-mapper-smoke.apex --target-org value-mapper
```

Run the smoke command only after the deployment reports `Succeeded`. If deployment continues asynchronously or times out, use its returned ID:

```sh
sf project deploy report --job-id DEPLOYMENT_ID --target-org value-mapper --wait 30
```

The smoke check validates installed configuration and exercises synthetic mappings in memory, without DML or callouts. Look for `VALUE_MAPPER_SMOKE_PASS`. An empty configuration is valid; lookups return `MISSING` until you add mappings.

`RunSpecifiedTests` checks this library. For your org's broader regression suite, add `--test-level RunLocalTests` to the installer or use that level in the deploy command, omitting `--tests`. Existing org tests may fail independently of this library. Production deployments must meet Salesforce's test and coverage requirements; specified tests require at least 75% coverage for each deployed class/trigger. See the [Salesforce deployment reference](https://developer.salesforce.com/docs/platform/salesforce-cli-reference/guide/cli_reference_project_deploy_start.html).

This is an **unpackaged source installation**, with no namespace. Review existing components for name collisions, especially `MappingResolver`, `MappingRequest`, and `Value_Mapping__mdt`, before deploying. For upgrades, review the new source and repeat the core install; existing mapping records are not included in that deployment. Back up your configuration and review breaking changes first. Uninstalling requires manually removing dependent consumer code, mapping records, and library metadata.

No managed/unlocked package or one-click installation link has been published. [Verification results](docs/deployment-verification.md) record the latest deployment and test results in the maintainer’s `valueMapper` Developer Edition org. Fresh-org installation and production compatibility have not yet been verified.

## Optional demo mappings

To try the example below, explicitly install the four fictional demo records:

```sh
bash scripts/install.sh --target-org value-mapper --with-examples
```

Or, after installing the core library:

```sh
sf project deploy start --source-dir examples --target-org value-mapper --test-level RunSpecifiedTests --tests MappingResolverTest --tests MappingFlowActionTest --wait 30
sf apex run --file scripts/apex/value-mapper-demo.apex --target-org value-mapper
```

Wait for deployment success before running the demo. Its success marker is `VALUE_MAPPER_DEMO_PASS`. The records live in `examples/main/default/customMetadata`; reinstalling them overwrites records with those same DeveloperNames. Use them in a test org before adding your own configuration. The demo expects these records to remain unchanged.

### Create mapping records from CSV

[examples/csv/value-mappings.csv](examples/csv/value-mappings.csv) contains the same four demo mappings. From the repository root, generate source metadata, then deploy it to your org:

```sh
sf cmdt generate records --csv examples/csv/value-mappings.csv --type-name Value_Mapping__mdt --output-directory examples/main/default/customMetadata
sf project deploy start --source-dir examples/main/default/customMetadata --target-org valueMapper --test-level RunSpecifiedTests --tests MappingResolverTest --tests MappingFlowActionTest --wait 30
sf apex run --file scripts/apex/value-mapper-demo.apex --target-org valueMapper
```

Replace `valueMapper` with your own authorized org alias. **Generation writes local XML files; deployment creates or updates the org records.** The CSV `Name` column supplies each record's DeveloperName and label. Blank provider/version cells mean common/base; `Active__c` uses `true` or `false`. Edit the CSV for your integration and use distinct record names to avoid overwriting existing configuration. Review generated XML before deployment. Run the demo script only with the supplied sample values. See the [Salesforce CLI command reference](https://developer.salesforce.com/docs/platform/salesforce-cli-reference/guide/cli_reference_cmdt_generate_records.html).

No mapper-specific permission set is required for calls from other Apex. Consumers own entry-point authorization, class access for exposed endpoints, and logging decisions. Administrators need the normal Salesforce permissions to manage Custom Metadata. There is no end-user admin UI in this release. Flow consumers use the action described below.

## Apex usage

### Load an integration's mappings once

For integrations with many fields, load all effective values for a provider/version as a nested map:

```apex
Map<String, Map<String, String>> parcel = MappingResolver.loadValues('ParcelDemo', 'V2');
String employmentCode = parcel.get('EmploymentType').get('Part time'); // EMP_PART

Map<String, Map<String, String>> route = MappingResolver.loadValues('RouteDemo', 'V2');
String routeEmploymentCode = route.get('EmploymentType').get('Part time'); // PART_TIME (common demo fallback)
```

Reuse the map for all fields and records in the integration. One call queries only that provider plus common mappings, validates the selected configuration once, and calculates effective values across every mapping type/source for the requested version. It uses the same precedence as individual resolution: common base → common version → provider base → provider version. Inactive rows, other providers, and other versions do not appear in the returned map. Blank provider means common only; blank version means base only. Provider/version normalization and exact case-sensitive mapping type/source keys are unchanged.

No `MappingRequest` is needed per lookup. Missing source keys return null. If a mapping type might be absent, use safe navigation to avoid dereferencing a null inner map:

```apex
String optionalValue = parcel.get('OptionalType')?.get('incoming value');
```

An empty effective configuration returns an empty map. Invalid selected configuration throws `MappingResolver.ConfigurationException` before any map is returned; catch it once at your integration boundary if needed. This includes conflicts in other versions of the selected provider or in shared configuration. The map API uses lenient unknown-version fallback to base values and does not return warnings, provenance, defaults, or a digest. Use `resolve`/`resolveAll` when you need those diagnostics or strict-version rejection. Each returned map is caller-owned; changing it does not change metadata, cached snapshots, or later loads. Metadata snapshots are cached per provider set within the transaction; each `loadValues` call rebuilds its effective map, so retain and reuse it.

For tests or an already-loaded snapshot, use `MappingResolver.loadValues(provider, version, snapshot)`. As with the existing snapshot APIs, validation covers the entire supplied snapshot; provider/version filtering controls the returned values.

### Resolve with diagnostics

After installing the optional demo mappings:

```apex
MappingRequest request = new MappingRequest(
    'ParcelDemo', 'V2', 'EmploymentType', 'Part time'
);
request.missingPolicy = 'ERROR';
MappingResult result = MappingResolver.resolve(request);
if (result.status == 'RESOLVED') {
    String outgoingEmploymentCode = result.value; // EMP_PART
} else {
    // Caller decides whether to stop or report the integration.
    System.debug(result.issues);
}
System.debug(JSON.serializePretty(result));
```

The result includes `status`, `value`, `winner` (DeveloperName), `layer`, `fallbackUsed`, `configDigest`, `shadowedRecords`, and `issues`. Diagnostics contain `code`, `severity`, `message`, and affected `records`.

```json
{
  "status": "RESOLVED",
  "value": "EMP_PART",
  "winner": "ParcelDemo_V2_Employment_PartTime",
  "layer": "PROVIDER_VERSION",
  "fallbackUsed": false,
  "shadowedRecords": [
    "Common_Employment_PartTime",
    "Common_V2_Employment_PartTime",
    "ParcelDemo_Employment_PartTime"
  ],
  "issues": []
}
```

The actual result also includes a SHA-256 `configDigest`.

## Flow usage

In Flow Builder, add an **Action → Apex → Resolve Value Mappings** (`MappingFlowAction`, category **Value Mapper**). Use an after-save record-triggered flow, autolaunched flow, or screen flow that supports Apex actions. Configure one mapping per action/interview; Salesforce groups interviews reaching the action into a bulk invocation. The adapter sends the entire input batch through one provider-scoped resolver call and returns one output per input in order. This follows the [Salesforce invocable action contract](https://developer.salesforce.com/docs/platform/apex-dev/references/apex-dev/apex-classes-annotation-invocablemethod.html). It performs no DML or callouts.

| Input | Usage |
| --- | --- |
| Mapping Type | Required, exact category such as `EmploymentType` |
| Source Value | Required, exact incoming value such as `Part time` |
| Provider | Optional, e.g. `ParcelDemo`; blank uses common mappings |
| Version | Optional, e.g. `V2`; blank uses base mappings |
| Missing Policy | Blank defaults to `ERROR`; otherwise `ERROR`, `RETURN_NULL`, or `USE_DEFAULT` |
| Default Value | Required for `USE_DEFAULT` |
| Strict Version | Optional, defaults to false; true rejects unknown versions |

With the demo records, set Provider=`ParcelDemo`, Version=`V2`, Mapping Type=`EmploymentType`, Source Value=`Part time`. Store **Status**, **Mapped Value**, **Has Errors**, and **Issue Messages** in Flow variables. Add a Decision after the action: use Mapped Value only when Status is `RESOLVED` or `DEFAULTED`. The example returns `RESOLVED` and `EMP_PART`.

`MISSING`, `INVALID_REQUEST`, and `INVALID_CONFIG` are normal outputs; route them to your Flow's error/review path. `RETURN_NULL` produces `MISSING` with Has Errors=false, so always check Status as well. Unknown-version warnings can accompany a successful result; inspect Issue Codes and Fallback Used if your integration must reject fallback. Configuration validation covers every selected provider plus common mappings; an invalid selected configuration affects the entire invocation.

Other outputs are **Winning Record**, **Winning Layer**, **Fallback Used**, **Configuration Digest**, **Shadowed Records** (text collection), **Issue Codes** and **Issue Messages** (aligned text collections), and **Issues JSON** (full diagnostics including severity and affected records). Has Errors is true when any diagnostic has severity `ERROR`. Keep a Fault connector for platform exceptions; ordinary mapping failures do not raise Flow faults. Grant the executing user Apex class access to `MappingFlowAction` where required by the Flow's execution context.

For Apex callers, the same action accepts a batch:

```apex
MappingFlowAction.Input input = new MappingFlowAction.Input();
input.provider = 'ParcelDemo';
input.version = 'V2';
input.mappingType = 'EmploymentType';
input.sourceValue = 'Part time';
List<MappingFlowAction.Output> outputs = MappingFlowAction.resolve(
    new List<MappingFlowAction.Input>{input}
);
System.debug(outputs[0].status); // RESOLVED with demo records
System.debug(outputs[0].value);  // EMP_PART
```

The outer list represents bulk Flow interviews; this action does not expose a collection input for multiple mappings within a single interview. Apex consumers that already have `MappingRequest` objects can continue using `MappingResolver.resolveAll` directly.

## Configuration and precedence

Manage records at **Setup → Custom Metadata Types → Value Mapping → Manage Records**, or create reviewed source records in `force-app/main/default/customMetadata` and deploy them alongside the library. This directory is intentionally empty in a fresh clone; create it when adding your own records. Keep provider/version blank for common/base scopes. Use your own mapping type and source/target strings; the library does not hard-code `EmploymentType` or `ParcelDemo`.

| Field | Rule |
| --- | --- |
| `DeveloperName` | Stable identifier returned as provenance |
| `Provider_Key__c` | Blank means common; otherwise trimmed and lowercased |
| `Version_Key__c` | Blank means base; otherwise trimmed and uppercased |
| `Mapping_Type__c` | Required; exact case-sensitive match |
| `Source_Value__c` | Required nonempty string; exact case-sensitive match |
| `Target_Value__c` | Required nonblank output, preserved as configured |
| `Active__c` | Only true records participate |

Text fields support up to 100 characters for scopes/category and 255 for source/target. Null and empty sources are unsupported. Whitespace in source/category is not normalized by the resolver. Salesforce's metadata editor/storage behavior still applies when saving records. Literal `Common` and `Base` are ordinary keys; use blank fields for shared/base scopes.

Highest matching layer wins, in this order from lowest to highest:

1. `COMMON_BASE`
2. `COMMON_VERSION`
3. `PROVIDER_BASE`
4. `PROVIDER_VERSION`

Provider base deliberately overrides common requested version. Shadowed records appear in ascending layer order. `fallbackUsed` is true when resolution uses a lower layer than the most specific requested scope, an unknown version falls back, or the caller default is used. A successful lower-layer match does not require a warning; unknown versions do.

A requested version is known when any active record with the same exact mapping type defines it in the requested provider or common scope, regardless of source value. Unrelated providers/categories cannot make a version known. Unknown versions produce `UNKNOWN_VERSION` with severity `WARNING` and use base mappings. Set `request.strictVersion = true` to return `INVALID_REQUEST` with an error instead.

## Missing values and invalid inputs

| `missingPolicy` | Missing result |
| --- | --- |
| `ERROR` (default) | `MISSING`, null value, `MISSING_MAPPING` error |
| `RETURN_NULL` | `MISSING`, null value, no missing-mapping diagnostic |
| `USE_DEFAULT` | `DEFAULTED`, caller's `defaultValue`, `fallbackUsed = true` |

Policy names are exact uppercase strings. `USE_DEFAULT` requires a nonblank default even if a mapping exists. Null requests, blank categories, null/empty sources, and invalid policies/defaults produce `INVALID_REQUEST`. A null request list is treated as an empty batch. An unresolved value is never silently passed through.

**Validation applies to the whole selected snapshot.** Any invalid active definition, duplicate normalized identity (provider/version/category/source), duplicate record identifier, or null snapshot/row returns `INVALID_CONFIG` for every request. Missing policies cannot hide configuration errors. A normal call selects the requested providers plus common records; unrelated provider errors do not block it. Shared configuration errors still affect every selected provider. An explicit whole-org snapshot validates all providers together. Inactive definitions, including invalid inactive fields, are ignored. Ordinary missing results do not throw exceptions; callers own error handling.

## Bulk calls and snapshots

```apex
List<MappingRequest> requests = new List<MappingRequest>{
    new MappingRequest('ParcelDemo', 'V2', 'EmploymentType', 'Part time'),
    new MappingRequest(null, null, 'EmploymentType', 'Part time')
};
List<MappingResult> results = MappingResolver.resolveAll(requests);
// Results preserve request order: EMP_PART, PT.
```

Normal `resolve` and `resolveAll` calls collect providers from the requests and issue a filtered metadata query for those providers **plus common mappings**. They load all mapping types, versions, and active/inactive records within that scope. Null/empty request lists return immediately without loading metadata. Each batch builds one validated lookup index; prefer a bulk call over repeated singleton calls. Resolution performs no DML or callouts.

For a point-to-point integration, load the entire provider configuration once and reuse it for several mapping categories:

```apex
MappingSnapshot providerConfig = MappingRepository.loadSnapshot(
    new Set<String>{'ParcelDemo'}
);
List<Value_Mapping__mdt> configRows = providerConfig.getRecords();
List<ConfigIssue> configIssues = MappingResolver.validateSnapshot(providerConfig);
List<MappingResult> results = MappingResolver.resolveAll(new List<MappingRequest>{
    new MappingRequest('ParcelDemo', 'V2', 'EmploymentType', 'Part time'),
    new MappingRequest('ParcelDemo', null, 'EmploymentType', 'Part time')
}, providerConfig);
// With demo records: EMP_PART, P_TIME. Check each result.status before use.
```

For several integrations, provide all relevant keys:

```apex
MappingSnapshot integrations = MappingRepository.loadSnapshot(
    new Set<String>{'ParcelDemo', 'RouteDemo'}
);
// All configuration for both providers, plus shared common mappings.
List<Value_Mapping__mdt> integrationRows = integrations.getRecords();

// Explicit audit of every provider in the org:
List<ConfigIssue> orgIssues = MappingResolver.validateSnapshot(
    MappingRepository.loadSnapshot()
);
```

Provider keys are trimmed, lowercased, deduplicated and sorted for the transaction cache. The same normalized provider set reuses its snapshot regardless of order. A different set causes another filtered query; cache entries live only for the current transaction. A null/empty set loads common mappings only. `loadSnapshot()` with no argument explicitly loads and caches the entire org configuration for audits. These are separate cache entries. Pass requests only for providers included in an explicit snapshot: an omitted provider can still resolve using common fallbacks.

A batch's validation and `configDigest` cover the union of its providers plus common records. A digest may therefore differ from a singleton result with identical output. Invalid active records in any provider selected for a batch invalidate the entire batch; use separate snapshots to isolate independent integrations.

For fixtures or independent configurations, create `new MappingSnapshot(List<Value_Mapping__mdt>)`, then use `MappingResolver.resolve(request, snapshot)`, `resolveAll(requests, snapshot)`, or `validateSnapshot(snapshot)`. Snapshots defensively clone input records and records returned by `getRecords()`. Results and diagnostics can be changed by the caller without modifying other results or cached configuration.

The digest hashes a sorted canonical representation of all selected configuration fields, including inactive rows and original provider/version spelling. Record order does not affect it; configuration content changes do. It identifies configuration, rather than only effective outputs. Retain the snapshot records alongside its digest to reproduce historical behavior. There is no persistent cache or telemetry.

## Source layout and verification scope

- `MappingRequest`, `MappingResult`, `ConfigIssue`: public request, result and diagnostic DTOs.
- `MappingSnapshot`: defensive snapshot and SHA-256 digest.
- `MappingRepository`: transaction-local metadata loader.
- `MappingResolver`: validation, precedence, exact lookup, nested value maps, and bulk API.
- `MappingResolverTest`: fixture-based Apex tests plus metadata cache verification.
- `MappingFlowAction`: bulk invocable Apex adapter for Flow.
- `MappingFlowActionTest`: adapter tests for 200 inputs, policies, diagnostics, and repository delegation.
- `force-app`: core library, schema, and tests; no supplied mapping records.
- `examples`: optional package directory with four fictional `EmploymentType` demo records. Always select `--source-dir force-app` for a core-only deployment; commands that deploy all package directories may also include examples.
- `scripts/install.sh`: installation into an explicitly selected org.
- `scripts/apex/value-mapper-smoke.apex`: configuration-independent installation check.
- `scripts/apex/value-mapper-demo.apex`: optional installed-demo check.

Tests cover all precedence layers, provider base versus common version, normalization, case-sensitive inputs, conflict rejection, inactive/invalid records, missing policies, strict/lenient versions, scope-specific version knowledge, ordered 200-request batches, snapshot isolation, deterministic digests, collision-safe keys, result isolation, and transaction-local cache reuse. They do not depend on org-specific business data.

The batch test uses four synthetic mapping records and 200 requests; it does not establish a maximum supported configuration size. The default loader reads only selected providers and shared mappings into an in-memory index; explicit whole-org loads read all records. Heap, CPU and applicable platform limits still apply, especially when many distinct provider sets are cached in one transaction. Measure realistic configuration volumes before integration use. Large-scale benchmarks, clean-org verification, packaging, snapshot comparison and an admin UI remain future work. Repository visibility is managed by the maintainer; these changes do not publish the repository or a package.

Store non-secret configuration only. Consumer applications own external-provider contracts, authorization, logging, and application-specific fixtures.

## Development and contributing

Run the Apex tests in an authorized org:

```sh
sf apex run test --class-names MappingResolverTest --class-names MappingFlowActionTest --target-org value-mapper --code-coverage --result-format human --wait 30
```

The installer has local boundary checks using Python 3 and a mock CLI; these do not deploy anything or substitute for Apex tests:

```sh
python3 -m unittest discover -s scripts/tests -v
```

For clean-org verification, authorize your own Dev Hub, create a scratch org, and install the core without demo records:

```sh
sf org login web --alias value-mapper-hub --set-default-dev-hub
sf org create scratch --definition-file config/project-scratch-def.json --target-dev-hub value-mapper-hub --alias value-mapper-clean --duration-days 1
bash scripts/install.sh --target-org value-mapper-clean
```

Then optionally install the demo using `--with-examples`. Delete the scratch org when finished with `sf org delete scratch --target-org value-mapper-clean`. Dev Hub is needed only for this development workflow, not normal installation.

Report issues with synthetic mapping records, the request, expected/actual results, library commit, and API version. Omit credentials and customer data. Include Apex tests when changing resolver behavior.

## License

[MIT](LICENSE). You may use, modify, and redistribute the library under its terms.
