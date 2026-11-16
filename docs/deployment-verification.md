# Deployment verification

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
