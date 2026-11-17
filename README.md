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

The installer deploys only the library, Custom Metadata Type, and tests. **No mapping records are installed by default.** It explicitly targets the org you supply, runs `MappingResolverTest`, and runs a smoke check after a successful deployment. It stops on deployment errors, pending deployments, and smoke failures. The dry run saves no changes and skips the smoke check.

Without Bash, run the equivalent commands from the repository root (also usable in PowerShell):

```sh
sf project deploy start --source-dir force-app --target-org value-mapper --test-level RunSpecifiedTests --tests MappingResolverTest --wait 30
sf apex run --file scripts/apex/value-mapper-smoke.apex --target-org value-mapper
```

Run the smoke command only after the deployment reports `Succeeded`. If deployment continues asynchronously or times out, use its returned ID:

```sh
sf project deploy report --job-id DEPLOYMENT_ID --target-org value-mapper --wait 30
```

The smoke check validates installed configuration and exercises synthetic mappings in memory, without DML or callouts. Look for `VALUE_MAPPER_SMOKE_PASS`. An empty configuration is valid; lookups return `MISSING` until you add mappings.

`RunSpecifiedTests` checks this library. For your org's broader regression suite, add `--test-level RunLocalTests` to the installer or use that level in the deploy command, omitting `--tests`. Existing org tests may fail independently of this library. Production deployments must meet Salesforce's test and coverage requirements; specified tests require at least 75% coverage for each deployed class/trigger. See the [Salesforce deployment reference](https://developer.salesforce.com/docs/platform/salesforce-cli-reference/guide/cli_reference_project_deploy_start.html).

This is an **unpackaged source installation**, with no namespace. Review existing components for name collisions, especially `MappingResolver`, `MappingRequest`, and `Value_Mapping__mdt`, before deploying. For upgrades, review the new source and repeat the core install; existing mapping records are not included in that deployment. Back up your configuration and review breaking changes first. Uninstalling requires manually removing dependent consumer code, mapping records, and library metadata.

No managed/unlocked package or one-click installation link has been published. [Verification results](docs/deployment-verification.md) include a successful core deployment dry run, 15 passing Apex tests, and both smoke checks in an existing Developer Edition org. Fresh-org installation and production compatibility have not yet been verified.

## Optional demo mappings

To try the example below, explicitly install the four fictional demo records:

```sh
bash scripts/install.sh --target-org value-mapper --with-examples
```

Or, after installing the core library:

```sh
sf project deploy start --source-dir examples --target-org value-mapper --test-level RunSpecifiedTests --tests MappingResolverTest --wait 30
sf apex run --file scripts/apex/value-mapper-demo.apex --target-org value-mapper
```

Wait for deployment success before running the demo. Its success marker is `VALUE_MAPPER_DEMO_PASS`. The records live in `examples/main/default/customMetadata`; reinstalling them overwrites records with those same DeveloperNames. Use them in a test org before adding your own configuration. The demo expects these records to remain unchanged.

No mapper-specific permission set is required for calls from other Apex. Consumers own entry-point authorization, class access for exposed endpoints, and logging decisions. Administrators need the normal Salesforce permissions to manage Custom Metadata. There is no end-user UI or Flow adapter in this release.

## Apex usage

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

**Validation applies to the whole snapshot.** Any invalid active definition, duplicate normalized identity (provider/version/category/source), duplicate record identifier, or null snapshot/row returns `INVALID_CONFIG` for every request. Missing policies cannot hide configuration errors. Inactive definitions, including invalid inactive fields, are ignored. Ordinary missing results do not throw exceptions; callers own error handling.

## Bulk calls and snapshots

```apex
List<MappingRequest> requests = new List<MappingRequest>{
    new MappingRequest('ParcelDemo', 'V2', 'EmploymentType', 'Part time'),
    new MappingRequest(null, null, 'EmploymentType', 'Part time')
};
List<MappingResult> results = MappingResolver.resolveAll(requests);
// Results preserve request order: EMP_PART, PT.
```

`MappingRepository.loadSnapshot()` queries the configuration once per Apex transaction. Each `resolveAll` builds one validated lookup index and resolves the batch against that snapshot. Prefer one bulk call over repeated singleton calls. Resolution performs no DML or callouts.

For fixtures or independent configurations, create `new MappingSnapshot(List<Value_Mapping__mdt>)`, then use `MappingResolver.resolve(request, snapshot)`, `resolveAll(requests, snapshot)`, or `validateSnapshot(snapshot)`. Snapshots defensively clone input records and records returned by `getRecords()`. Results and diagnostics can be changed by the caller without modifying other results or cached configuration.

The digest hashes a sorted canonical representation of all selected configuration fields, including inactive rows and original provider/version spelling. Record order does not affect it; configuration content changes do. It identifies configuration, rather than only effective outputs. Retain the snapshot records alongside its digest to reproduce historical behavior. There is no persistent cache or telemetry.

## Source layout and verification scope

- `MappingRequest`, `MappingResult`, `ConfigIssue`: public request, result and diagnostic DTOs.
- `MappingSnapshot`: defensive snapshot and SHA-256 digest.
- `MappingRepository`: transaction-local metadata loader.
- `MappingResolver`: validation, precedence, exact lookup, and bulk API.
- `MappingResolverTest`: fixture-based Apex tests plus metadata cache verification.
- `force-app`: core library, schema, and tests; no supplied mapping records.
- `examples`: optional package directory with four fictional `EmploymentType` demo records. Always select `--source-dir force-app` for a core-only deployment; commands that deploy all package directories may also include examples.
- `scripts/install.sh`: installation into an explicitly selected org.
- `scripts/apex/value-mapper-smoke.apex`: configuration-independent installation check.
- `scripts/apex/value-mapper-demo.apex`: optional installed-demo check.

Tests cover all precedence layers, provider base versus common version, normalization, case-sensitive inputs, conflict rejection, inactive/invalid records, missing policies, strict/lenient versions, scope-specific version knowledge, ordered 200-request batches, snapshot isolation, deterministic digests, collision-safe keys, result isolation, and transaction-local cache reuse. They do not depend on org-specific business data.

The batch test uses four synthetic mapping records and 200 requests; it does not establish a maximum supported configuration size. The loader reads all records and builds an in-memory index, so heap, CPU and query-row limits apply. Measure realistic configuration volumes before integration use. Large-scale benchmarks, clean-org verification, packaging, snapshot comparison, Flow support and an admin UI remain future work. Repository visibility is managed by the maintainer; these changes do not publish the repository or a package.

Store non-secret configuration only. Consumer applications own external-provider contracts, authorization, logging, and application-specific fixtures.

## Development and contributing

Run the Apex tests in an authorized org:

```sh
sf apex run test --class-names MappingResolverTest --target-org value-mapper --code-coverage --result-format human --wait 30
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
