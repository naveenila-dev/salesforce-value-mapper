# Salesforce Value Mapper

Load a provider's mappings once, then look up values with a nested Apex map:

```apex
Map<String, Map<String, String>> mappings = MappingResolver.loadValues('ParcelDemo', 'V2');
String value = mappings.get('EmploymentType')?.get('Part time'); // EMP_PART with demo records
```

Reuse `mappings` for all fields and records in the integration. The library contains two production classes: `MappingResolver` and the optional Flow adapter `MappingFlowAction`. Configuration lives in `Value_Mapping__mdt`. There is no DML, callout, persistent cache, or external dependency.

## Install

Use Salesforce CLI with an authorized org supporting Apex and Custom Metadata, API 65.0 or later. From the repository root:

```sh
# Authorize your own org; use https://test.salesforce.com for a sandbox.
sf org login web --alias value-mapper --instance-url https://login.salesforce.com

bash scripts/install.sh --target-org value-mapper --dry-run
bash scripts/install.sh --target-org value-mapper
```

The installer deploys the library, metadata type and tests, runs both test classes, then runs the core smoke check. It does not install mapping records by default. Its dry run saves no changes. Use `--test-level RunLocalTests` for the broader org suite. Alternatively:

```sh
sf project deploy start --source-dir force-app --target-org value-mapper --test-level RunSpecifiedTests --tests MappingResolverTest --tests MappingFlowActionTest --wait 30
sf apex run --file scripts/apex/value-mapper-smoke.apex --target-org value-mapper
```

Run the smoke check only after deployment reports `Succeeded`; look for `VALUE_MAPPER_SMOKE_PASS`. If the deployment is still running, check its returned ID with `sf project deploy report --job-id DEPLOYMENT_ID --target-org value-mapper --wait 30`.

This is an unpackaged source installation with no namespace or published package. Check for component name collisions before installing. Start in a Developer Edition org or sandbox. Fresh-org installation and production compatibility have not been verified; see the latest [deployment verification](docs/deployment-verification.md).

## Sample records from CSV

The [sample CSV](examples/csv/value-mappings.csv) defines four fictional mappings. Generate local metadata files, deploy them, then run the example:

```sh
sf cmdt generate records --csv examples/csv/value-mappings.csv --type-name Value_Mapping__mdt --output-directory examples/main/default/customMetadata
sf project deploy start --source-dir examples/main/default/customMetadata --target-org valueMapper --test-level RunSpecifiedTests --tests MappingResolverTest --tests MappingFlowActionTest --wait 30
sf apex run --file scripts/apex/value-mapper-demo.apex --target-org valueMapper
```

Replace `valueMapper` with your authorized org alias. Generation writes XML locally; deployment creates or updates org records. `Name` supplies DeveloperName and label. Blank provider/version cells mean shared/base, and `Active__c` uses `true` or `false`. Review generated files before deploying: matching DeveloperNames are overwritten. The demo expects the supplied values and prints `VALUE_MAPPER_DEMO_PASS`.

You can also install the existing sample XML with `bash scripts/install.sh --target-org value-mapper --with-examples`.

## Apex usage

```apex
Map<String, Map<String, String>> parcel = MappingResolver.loadValues('ParcelDemo', 'V2');
Map<String, Map<String, String>> route = MappingResolver.loadValues('RouteDemo', 'V2');

String employmentCode = parcel.get('EmploymentType')?.get('Part time'); // EMP_PART
String routeCode = route.get('EmploymentType')?.get('Part time');       // PART_TIME, shared fallback
String optionalValue = parcel.get('OptionalType')?.get('source');       // null
```

A missing category or source returns null with this safe-navigation pattern. An empty configuration returns an empty map. Supply a caller default when appropriate:

```apex
String value = mappings.get('OptionalType')?.get('source');
if (value == null) { value = 'UNKNOWN'; }
```

Each `loadValues` call queries only the provider plus shared records and builds a fresh map. Retain the map and reuse it throughout your integration; changing it does not change org configuration. There are no per-value request/result objects.

For multiple providers, load their entire configuration once, including every version and active/inactive record, then build maps from those rows:

```apex
List<Value_Mapping__mdt> config = MappingResolver.loadRecords(new Set<String>{'ParcelDemo', 'RouteDemo'});
Map<String, Map<String, String>> parcel = MappingResolver.loadValues('ParcelDemo', 'V2', config);
Map<String, Map<String, String>> route = MappingResolver.loadValues('RouteDemo', 'V2', config);
```

`loadRecords(null)` or an empty set loads shared records only. The overload accepting records also supports in-memory test fixtures.

## Configuration rules

Manage records in **Setup → Custom Metadata Types → Value Mapping → Manage Records**, or add source records and deploy them.

| Field | Meaning |
| --- | --- |
| `Provider_Key__c` | Blank for shared mappings; otherwise trimmed and matched without case sensitivity |
| `Version_Key__c` | Blank for base mappings; otherwise trimmed and matched without case sensitivity |
| `Mapping_Type__c` | Required, exact case-sensitive category |
| `Source_Value__c` | Required nonempty string, exact case-sensitive key |
| `Target_Value__c` | Required nonblank output, returned as configured |
| `Active__c` | Only true records participate |

Category and source whitespace is not normalized by the loader. Salesforce storage/editor behavior still applies. Literal `Common` and `Base` are ordinary keys: use blank fields for shared/base records.

The highest applicable definition wins:

1. Shared base
2. Shared requested version
3. Provider base
4. Provider requested version

Provider base overrides shared version. Blank version selects base only. Unknown versions use available base mappings. Inactive rows, unrelated providers and other versions are ignored when building a map.

Invalid active records or duplicate definitions of the same normalized provider/version/category/source in the selected scope throw `MappingResolver.ConfigurationException`. The call returns no partial map. Handle this once at the integration boundary if needed. Invalid records in an unrelated provider or version do not block the selected map. There are no strict-version policies, diagnostics DTOs, configuration digests, or per-value defaults; the caller handles missing values.

## Flow usage

In Flow Builder, select **Action → Apex → Resolve Value Mappings** under **Value Mapper**. Inputs are Provider, Version, Mapping Type, and Source Value; the last two are required. Blank provider/version selects shared/base mappings.

Outputs are **Mapped Value** and **Found**. Use a Decision on Found: true means use Mapped Value, false means handle the missing mapping or supply a default. With the demo inputs `ParcelDemo`, `V2`, `EmploymentType`, `Part time`, the output is `EMP_PART` and Found=true.

The adapter supports bulk Flow interviews: it loads all relevant providers in one query, builds one map per distinct provider/version, and returns one output per input in order. It does not expose a collection input for multiple mappings within a single interview. Invalid inputs or configuration raise a Flow fault for the invocation; connect the action's Fault path. Grant Apex class access to `MappingFlowAction` where required by the Flow's execution context.

## Upgrading from the earlier API

This simplified version is a breaking change. Replace `MappingRequest`/`MappingResult` and `resolve`/`resolveAll` calls with `loadValues` and map lookups. Replace `MappingRepository.loadSnapshot()` with `MappingResolver.loadRecords(providers)`. Snapshots, provenance, digests, missing policies, strict-version rejection, and detailed diagnostics have been removed. Update existing Flows to use the four inputs and two outputs above.

After migrating dependent Apex and Flows, deploy the simplified source and remove its five obsolete helper classes:

```sh
sf project deploy start --manifest manifest/package.xml --post-destructive-changes manifest/remove-legacy-mapper.xml --target-org value-mapper --test-level RunSpecifiedTests --tests MappingResolverTest --tests MappingFlowActionTest --wait 30
```

The cleanup manifest removes only `ConfigIssue`, `MappingRepository`, `MappingRequest`, `MappingResult`, and `MappingSnapshot`. Mapping records and the metadata type are retained. A normal source deployment alone does not remove old org classes. Use the normal install commands for new orgs.

## Tests

```sh
sf apex run test --class-names MappingResolverTest --class-names MappingFlowActionTest --target-org value-mapper --code-coverage --result-format human --wait 30
python3 -m unittest discover -s scripts/tests -v
```

Apex tests cover precedence, provider isolation, exact keys, duplicates, invalid records, 50/20-category integrations, independent returned maps, and 200 ordered Flow results. The Python tests check installer behavior using a mock CLI. These checks do not establish a maximum configuration size; measure Apex heap and CPU with realistic volumes.

## License

[MIT](LICENSE).
