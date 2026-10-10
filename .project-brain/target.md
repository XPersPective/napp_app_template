# Target Architecture
Status: CONFIRMED

## Goal
"Belgeye göre AI App Factory sistemini gerçekten kur ... Mevcut kodları koru ... yaptığın her işi gerçek testlerle doğrula." User authorizes extending existing Flutter starter.

## Target State
Generated free, ads-only, lifetime-only, lifetime+ads and optional monthly variants compile/test. Free excludes both SDKs. Banner/rewarded explicit; fullscreen OFF by default. Premium loads before SDK init and propagates changes. About/privacy/licenses/discover navigation with real translations. Monthly requires trusted verification/backend/store setup; generated default fails closed.

## Non-Goals
No push, signing, deployment, credentials, paid AI, new orchestration engine/dependency.

## Open Decisions
Live monthly BLOCKED by absent receipt backend/store products.

## Success Conditions
- Isolated generated variants pass analyze and meaningful widget/domain checks.
- Tool copies remain byte-identical.
- Missing monthly verifier prevents purchase and grants.