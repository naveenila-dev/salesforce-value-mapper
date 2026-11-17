# Deployment verification

## Current source changes

The reusable source-install workflow separates the four demo records into the
optional `examples` directory. The core smoke script now works without demos;
the previous demo smoke script is `scripts/apex/value-mapper-demo.apex`.
See the README for current installation commands. Org-specific identifiers below
are verification evidence, not required installation settings.

Live recheck on 17 November 2026 against the existing `crmaTh` Developer Edition
org:

- `bash scripts/install.sh --target-org crmaTh --dry-run --wait 1` succeeded.
- Validation ID: `0Afbm00000oTHyNCAW`; 14 core components validated, all unchanged.
- `MappingResolverTest`: **15 passed, 0 failed**.
- The new core smoke script compiled and executed successfully:
  `VALUE_MAPPER_SMOKE_PASS`.
- The optional demo smoke script compiled and executed successfully:
  `VALUE_MAPPER_DEMO_PASS`; output `EMP_PART`, expected provider/version winner,
  three shadowed records, no fallback or issues.
- Both scripts performed zero DML statements and zero callouts. Installed
  configuration digest remained
  `925ec1c142c86506eb43edc42bda3a1a15fcb06df3d8286f88baf4209354a7a4`.
- Validation saved no metadata changes. The org already has the demo records;
  this recheck does not establish clean-org installation or rerun all local org
  tests.

Local verification on 17 November 2026:

- Seven installer boundary tests passed using a mock Salesforce CLI, including
  explicit target selection, optional examples, dry runs, failed/pending deploys,
  smoke failures, and local-test selection.
- Bash syntax, JSON/XML parsing, and whitespace checks passed.
- Salesforce CLI converted both source directories to Metadata API format.
  The core manifest contains seven Apex classes and the Custom Metadata Type,
  with no Custom Metadata records. The examples manifest contains four records.
- Initial sandboxed credential access failed. The live recheck above succeeded
  with approved access to the saved Salesforce CLI credentials.

## Historical deployment

Verified on **17 November 2026 (Australia/Melbourne)** in the requested **crmaTh** Developer Edition org (`00Dbm00000qdYS8EAM`).

- Deployment: `0Afbm00000oSaK5CAK` — **Succeeded**, 18 components.
- Deployment test level: `RunSpecifiedTests`, `MappingResolverTest` — **15 passed, 0 failed**.
- Mapper coverage: **159/160 executable lines (99.4%)**; `MappingResolver` itself is **100%** covered.
- Installed-configuration smoke script: **passed**, compiled successfully, no exceptions.
- Smoke output: `EMP_PART`, winner `ParcelDemo_V2_Employment_PartTime`, layer `PROVIDER_VERSION`, three shadowed records, no fallback or issues.
- Configuration digest at smoke time: `925ec1c142c86506eb43edc42bda3a1a15fcb06df3d8286f88baf4209354a7a4`.

## Full org local test suite

Run `707bm00001WrsHG` completed: **33 passed, 2 failed**, 35 total. All 15 mapper tests passed in this run as well. The org-wide suite is therefore **not green**.

The failing existing tests exercise code outside this deployment:

| Test | Failure |
| --- | --- |
| `CrmaDatasetQueryApiTest.<compile>` | Line 48 calls a `CrmaDatasetQueryApi.buildSaql` signature that does not exist. |
| `DataManager_QuotaTest.testQueueable` | Line 14 expects 248 quota CSV lines; actual count is 261. |

Those existing classes were inspected read-only and were not changed. The successful mapper source deployment was not rolled back by the separate full-suite test run. A future deployment using `RunLocalTests` will require these org test failures to be addressed.

## Scope

This verifies deployment into the existing connected Developer Edition org, deterministic fixture behavior, and the installed demo metadata. Clean-org deployment, package creation/installation, other Salesforce editions and high-volume configuration benchmarks are not verified. No package has been published.
