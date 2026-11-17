# Deployment verification

Optional maintainer evidence; installation and usage are in the [README](../README.md).

Verified on **17 November 2026 (Australia/Melbourne)** in the requested
`valueMapper` Developer Edition org (`00DQy000012BqrFMAS`).

| Check | Result |
| --- | --- |
| Validation | `0AfQy00000ea3Q9KAI` — Succeeded, no changes saved |
| Deployment | `0AfQy00000ea3WbKAI` — Succeeded, 16 components including five class removals |
| Apex tests | `MappingResolverTest` and `MappingFlowActionTest`: **9 passed, 0 failed** |
| Production Apex coverage | `MappingResolver`: **40/40** lines; `MappingFlowAction`: **24/24** lines |
| Core and demo smoke checks | `VALUE_MAPPER_SMOKE_PASS` and `VALUE_MAPPER_DEMO_PASS` |
| Live Flow action | **200 ordered outputs verified** using the invocable action endpoint |
| Flow action schema | Four inputs (`provider`, `version`, `mappingType`, `sourceValue`), two outputs (`value`, `found`) |
| Local installer checks | **7 passed** using a mock Salesforce CLI |

The simplified library has two production classes. Deployment removed the
superseded `ConfigIssue`, `MappingRepository`, `MappingRequest`, `MappingResult`,
and `MappingSnapshot` classes. A pre-deployment inspection found no references
to those helpers in Apex outside the mapper library and its tests. The metadata
type and sample mapping records were retained.

The demo verified `ParcelDemo` / `V2` returns `EMP_PART`, provider base returns
`P_TIME`, `RouteDemo` / `V2` falls back to `PART_TIME`, and an absent category
returns null through safe navigation. The live Flow batch verified provider
and shared mappings, unknown-version base fallback, missing-value outputs, and
result order. No Flow was created or activated; Flow Builder interaction was
not tested.

Apex fixtures cover override order, normalized scopes, exact keys, duplicate
and invalid definitions, inactive rows, provider/version isolation, 50 categories
for one provider and 20 for another, caller-owned maps, and 200 Flow inputs.
Both smoke scripts perform no DML or callouts. XML/JSON parsing, Bash syntax,
and whitespace checks passed.

To reproduce, run the README installation or upgrade command, then:

```sh
sf apex run --file scripts/apex/value-mapper-smoke.apex --target-org valueMapper
sf apex run --file scripts/apex/value-mapper-demo.apex --target-org valueMapper
python3 -m unittest discover -s scripts/tests -v
```

The demo requires the supplied sample records. This verification covers an
existing Developer Edition org and the library's specified tests. Full-org
`RunLocalTests`, fresh-org installation, production compatibility, packaging,
and high-volume configuration benchmarks remain unverified.
