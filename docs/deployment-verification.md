# Deployment verification

This optional maintainer record captures the latest verified deployment. It is
not required to install or use the library; see the [README](../README.md) for
installation and usage. Org aliases and deployment IDs below are evidence, not
settings that other users need to copy.

## Latest verification: valueMapper

Verified on **17 November 2026 (Australia/Melbourne)** against the requested
**valueMapper** Developer Edition org (`00DQy000012BqrFMAS`). This is an existing
org, not a newly created scratch org.

| Check | Result |
| --- | --- |
| Core deployment | `0AfQy00000ea0bxKAA` — **Succeeded**, 16 components |
| Core deployment tests | `RunSpecifiedTests`, `MappingResolverTest` and `MappingFlowActionTest` — **25 passed, 0 failed** |
| Mapper coverage in core deployment | **239/240 executable lines (99.6%)**; `MappingResolver`, `MappingRepository`, and `MappingFlowAction` **100%** |
| CSV-generated demo deployment | `0AfQy00000eZzftKAC` — **Succeeded**, four Custom Metadata records |
| Demo deployment tests | `MappingResolverTest` — **16 passed, 0 failed** |
| Core smoke | Compiled and executed successfully; `VALUE_MAPPER_SMOKE_PASS` |
| Installed demo smoke | Compiled and executed successfully; `VALUE_MAPPER_DEMO_PASS` |
| Flow action discovery | HTTP 200; correct required inputs, scalar outputs, and text collections |
| Live invocable action batch | **200 ordered results verified** via the custom Apex action endpoint |
| Local installer tests | **7 passed**, using a mock Salesforce CLI |

The org had no `Value_Mapping__mdt` records before sample installation. The four
fictional demo records were generated from `examples/csv/value-mappings.csv`
using `sf cmdt generate records`, then deployed. Generation alone does not
create records in the org.

The installed demo resolved `Part time` for `ParcelDemo` / `V2` to `EMP_PART`,
with winner `ParcelDemo_V2_Employment_PartTime`, layer `PROVIDER_VERSION`, three
shadowed records, no fallback, and no issues. Its selected configuration digest
was `925ec1c142c86506eb43edc42bda3a1a15fcb06df3d8286f88baf4209354a7a4`.

The demo smoke also verified normalized provider cache reuse, inclusion of
shared mappings in the complete `ParcelDemo` configuration, exclusion of
`ParcelDemo` records from a `RouteDemo` snapshot, and common fallback for
`RouteDemo`. Apex tests cover provider-set normalization, multi-provider batch
selection, common-only loads, and agreement with an independently filtered
whole-org snapshot. Both smoke scripts perform no DML or callouts.

The Flow adapter was verified through
`/services/data/v65.0/actions/custom/apex/MappingFlowAction`: action discovery
reported label `Resolve Value Mappings`, category `Value Mapper`, required
`mappingType`/`sourceValue` inputs, and the expected output schema. A single
200-input POST verified result count and order across successful provider
mappings, missing mappings, caller defaults, strict unknown-version errors,
and shared fallback. All 200 action executions succeeded; mapping failures
were returned as statuses and diagnostics. No saved Flow was created or
activated, and Flow Builder interaction was not tested.

The nested-map API `MappingResolver.loadValues(provider, version)` was also
verified in this deployment. Fixture tests cover 50 mapping categories for one
provider and 20 for another, agreement with individual resolution, all override
layers, normalized scopes, unknown-version base fallback, case-sensitive keys,
exclusion of inactive/unrelated definitions, empty results, invalid configuration
rejection, and caller-owned maps. The updated demo smoke verified
`loadValues('ParcelDemo', 'V2').get('EmploymentType').get('Part time')` returns
`EMP_PART`, while `RouteDemo` uses the common version mapping `PART_TIME`.
The core smoke verified safe navigation for a missing mapping type.

## Reproduce

From the repository root, with the target org already authorized:

```sh
bash scripts/install.sh --target-org valueMapper
sf cmdt generate records --csv examples/csv/value-mappings.csv --type-name Value_Mapping__mdt --output-directory examples/main/default/customMetadata
sf project deploy start --source-dir examples/main/default/customMetadata --target-org valueMapper --test-level RunSpecifiedTests --tests MappingResolverTest --tests MappingFlowActionTest --wait 30
sf apex run --file scripts/apex/value-mapper-demo.apex --target-org valueMapper
python3 -m unittest discover -s scripts/tests -v
```

Wait for each deployment to report `Succeeded` before continuing. Generating and
deploying the sample overwrites those four DeveloperNames; review the target
configuration first. The core installer does not install sample records.

## Scope and limitations

These results verify the library and sample configuration in `valueMapper`.
The whole-org `RunLocalTests` suite was not run for this verification; the 25
passing tests are the resolver and Flow adapter suites only. Prior results from a different org do
not describe the health of this org and have been removed from this current
verification record.

Clean-org installation, production compatibility, other editions, package
installation, and high-volume configuration benchmarks remain unverified. No
package has been published. Default resolution now queries only requested
providers plus common mappings; `MappingRepository.loadSnapshot()` remains an
explicit whole-org audit API.
