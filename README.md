# Salesforce Value Mapper

Versioned value mappings, explicit override rules, and an explanation for every result.

An Apex library for exact string-to-string translation using `Value_Mapping__mdt`. Source is implemented in this project. No managed/unlocked package or public installation link has been published. No license has been selected; this repository does not yet grant a public open-source license.

Latest verification: [deployment and test results](docs/deployment-verification.md). The mapper deployment and smoke test passed; two existing org tests failed in the separate full-suite run.

## Deploy and verify

Requires Salesforce CLI, an authorized Apex-capable org, and permissions to deploy Apex and Custom Metadata. Source targets **API 65.0**. The deployment target for this implementation is the connected **crmaTh Developer Edition** org. Other editions and package installation have not been verified.

```sh
sf project deploy start --source-dir force-app --target-org crmaTh --test-level RunLocalTests --wait 10
sf apex run --file scripts/apex/value-mapper-smoke.apex --target-org crmaTh
```

If deployment continues asynchronously, use `sf project deploy report --job-id <deployment-id> --target-org crmaTh --wait 10` to confirm the final result. `RunLocalTests` includes existing local tests in the target org. For an isolated library check use `--test-level RunSpecifiedTests --tests MappingResolverTest` instead.

The smoke script asserts the shared default, provider/version override, winner, explanation, snapshot validity, and all three missing policies. It expects the four supplied fictional demo records to remain unchanged. It performs no DML or callouts.

No mapper-specific permission set is required for calls from other Apex. Consumers own entry-point authorization, class access for exposed endpoints, and logging decisions. Administrators need the normal Salesforce permissions to manage Custom Metadata. There is no end-user UI or Flow adapter in this release.

## Apex usage

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

Manage records at **Setup → Custom Metadata Types → Value Mapping → Manage Records**, or deploy reviewed source records from `force-app/main/default/customMetadata`.

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
- Four fictional `EmploymentType` sample records; no customer mappings.
- `scripts/apex/value-mapper-smoke.apex`: executable installed-configuration check.

Tests cover all precedence layers, provider base versus common version, normalization, case-sensitive inputs, conflict rejection, inactive/invalid records, missing policies, strict/lenient versions, scope-specific version knowledge, ordered 200-request batches, snapshot isolation, deterministic digests, collision-safe keys, result isolation, and transaction-local cache reuse. They do not depend on org-specific business data.

The batch test uses four synthetic mapping records and 200 requests; it does not establish a maximum supported configuration size. The loader reads all records and builds an in-memory index, so heap, CPU and query-row limits apply. Measure realistic configuration volumes before integration use. Large-scale benchmarks, clean-org installation, packaging, snapshot comparison, Flow support and an admin UI remain future work. Public publishing and license selection are separate release steps.

Store non-secret configuration only. Consumer applications own external-provider contracts, authorization, logging, and application-specific fixtures.
