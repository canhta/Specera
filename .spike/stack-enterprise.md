# S5 — Enterprise foundations: auth, tenancy, audit, deployment, compliance

All liveness/licence rows via `gh api repos/<r>` on **2026-08-04**.

## 0. Dependency ledger (every recommended or considered dep)

| Repo | Licence | Stars | Last push | Archived | Verdict |
|---|---|---|---|---|---|
| `ory/polis` (ex `boxyhq/jackson`) | Apache-2.0 (LICENSE file read) | 2257 | 2026-07-27 | false | **ADOPT** — SAML/SCIM bridge |
| `keycloak/keycloak` | Apache-2.0 | 35976 | 2026-08-04 | false | Runner-up |
| `goauthentik/authentik` | API `NOASSERTION`; LICENSE = **MIT core + proprietary `authentik/enterprise/`** | 22596 | 2026-08-04 | false | Reject — open-core split |
| `zitadel/zitadel` | **AGPL-3.0** | 14630 | 2026-08-03 | false | Reject — copyleft (§1) |
| `ory/hydra` / `kratos` / `keto` | Apache-2.0 | 17453/13810/5382 | 2026-07-29/07-29/08-03 | false | Not needed — we are an RP, not an IdP |
| `nextauthjs/next-auth` (Auth.js) | ISC | 28316 | 2026-07-22 | false | Adopt **only if S1 picks TS** |
| `openfga/openfga` | Apache-2.0 | 5539 | 2026-08-03 | false | Defer to v2 (§2) |
| `cedar-policy/cedar` | Apache-2.0 | 1636 | 2026-07-31 | false | Defer to v2 |
| `apache/casbin` | Apache-2.0 | 20305 | 2026-08-04 | false | Not needed for v1 model |
| `osohq/oso` | Apache-2.0 | 3492 | **2025-02-26** | false | Reject — 17 months no push |
| `sigstore/timestamp-authority` | Apache-2.0 | 136 | 2026-08-03 | false | Adopt (self-host RFC 3161) |
| `digitorus/timestamp` | BSD-2-Clause | 83 | 2025-05-24 | false | Client lib; low bus factor — flag |
| `sigstore/rekor` / `fulcio` | Apache-2.0 | 1187/865 | 2026-08-03 | false | **Reject public instance** (§3) |
| `google/trillian` | Apache-2.0 | 3740 | 2026-08-03 | false | Defer to v2 (private log) |
| `openbao/openbao` | MPL-2.0 (weak copyleft, file-level — safe as external service) | 6917 | 2026-08-03 | false | Optional external KMS |
| `hashicorp/vault` | API `NOASSERTION`; LICENSE = **BUSL-1.1** (IBM) | 36057 | 2026-08-03 | false | Reject — non-open source |
| `getsops/sops` | MPL-2.0 | 22679 | 2026-08-03 | false | Adopt for Helm secrets |
| `external-secrets/external-secrets` | Apache-2.0 | 6772 | 2026-08-03 | false | Optional, K8s tier |
| `open-telemetry/opentelemetry-js` | Apache-2.0 | 3427 | 2026-08-03 | false | Adopt (exporter off by default) |
| `bitnami/charts` | `NOASSERTION` + 2025 registry paywall | 10392 | 2026-08-03 | false | **Do not depend on** for subcharts |
| WorkOS | commercial SaaS, closed | — | — | — | **Reject — see §1** |

---

## 1. Auth / SSO — **the app speaks OIDC only; SAML arrives via a bridge**

**Correction to a brief `FACT`.** The brief states sourcebot uses BoxyHQ Jackson. `FACT` It does not, in the cloned tree (full clone, 1358 commits): `git log -S"jackson" --all` and `-S"saml"` return **zero commits**, and no file matches `boxyhq|jackson` case-insensitively. `FACT` `sourcebot/packages/web/package.json` has `next-auth ^5.0.0-beta.32` + `@auth/prisma-adapter`; `packages/web/src/ee/features/sso/sso.ts` builds providers for Okta, Keycloak, MicrosoftEntraID, Authentik, JumpCloud, Bitbucket, GCP-IAP — **all OIDC/OAuth, no SAML** — and SCIM is hand-rolled (`packages/web/src/ee/features/scim/`, `ScimToken` model in `packages/db/prisma/schema.prisma:461`). `FACT` Greptile *does* use Jackson (`.spike/evidence-greptile.md:137`). One of the two data points behind "both use Jackson" does not hold.

**What changed with Jackson.** `FACT` `boxyhq/jackson` now 301-redirects to **`ory/polis`** — BoxyHQ's SSO product was taken over by Ory and renamed. Apache-2.0, not archived, pushed 2026-07-27. `FACT` Release history shows `v1.52.1` (2025-07-14) then a gap to `v26.2.0` (2026-03-20, the rename) and **no release since**, despite pushes. `FACT` Commits since are ~80% bot (`ory-bot`, `dependabot` 2714 contributions) but the original maintainers are still active — `deepakprabhakara` and `niwsa` land features (`fix: cross-tenant identity provider selection via idp_hint in Polis`, 2026-06-25). `INFERENCE` Maintenance-mode-plus under a larger sponsor: better bus factor than BoxyHQ standalone, worse feature velocity. A rename mid-spike is exactly the liveness trap the brief warns about — anyone pinning `@boxyhq/saml-jackson` from memory would have shipped a dead name.

**DECISION.** Specera's app is an **OIDC relying party and nothing else**, in every language. SAML 2.0 and SCIM 2.0 are served by **Ory Polis run as a separate container** that terminates SAML and presents OIDC inward. **Runner-up: Keycloak** (Apache-2.0, 36k stars, the strongest bus factor in the table) in identity-brokering mode — same architecture, heavier (JVM, own DB), and enterprises resent running a second IdP when they already have Entra/Okta.

Why this shape and not a library:
- `INFERENCE` It makes auth **independent of S1's language decision**. A Node-only choice (Auth.js) would bind the platform's procurement gate to one runtime.
- `FACT` Polis is Apache-2.0 with no open-core split — unlike authentik, whose LICENSE reserves `authentik/enterprise/`, and unlike Vault (BUSL-1.1).
- If Polis stalls, replacing one container that speaks OIDC inward is a swap, not a migration. That is the entire point.

**WorkOS: reject, plainly.** A commercial, closed, hosted-only auth dependency makes the "open-source, self-hostable, air-gapped, no-egress" claim false at the login page — every self-hoster would need a WorkOS account and every air-gapped install would be impossible. It is disqualified by the product's positioning, not by its quality.

**What would change my mind:** Polis going 12 months with no human feature commit → move to Keycloak brokering.

---

## 2. RBAC and multi-tenancy — **multi-tenant schema, single-tenant deployment**

**DECISION.** `org_id` (non-null, FK, indexed) on every tenant-scoped table from the **first migration**, plus Postgres **row-level security** keyed on a session GUC. v1 ships and is documented as single-tenant self-host; the schema never needs the retrofit.

`FACT` This is precisely sourcebot's answer, and the comment is explicit — `packages/db/prisma/schema.prisma:490`: `// Fast path for analytics queries – orgId is first because we assume most deployments are single tenant`. Every model (`Audit`, `ApiKey`, `ScimToken`, `License`, `Repo`) carries `orgId Int` with `onDelete: Cascade`. `INFERENCE` They pay ~zero for it single-tenant and the multi-tenant path stayed open. Adding `org_id` later means rewriting every query, every index, and every authorization check simultaneously — measured in quarters, not sprints.

**Permission model.** `FACT` sourcebot's `enum OrgRole { OWNER, MEMBER }` (schema.prisma:395) is two roles. That is too thin for a product that closes merge gates: it cannot express "may approve a gate but may not change the rule that gate enforces" — the separation of duties every auditor asks for first.

| Role | Graph read | Run analysis | Author/edit gate policy | Approve/override a gate | Manage members, SSO, keys | Read audit log |
|---|---|---|---|---|---|---|
| `OWNER` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `ADMIN` | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| `APPROVER` | ✓ | ✓ | — | ✓ | — | ✓ |
| `MEMBER` | ✓ | ✓ | — | — | — | own actions |
| `VIEWER` | ✓ | — | — | — | — | — |
| `SERVICE` (CI/API key) | scoped | ✓ | — | — | — | — |

`ADMIN` × `APPROVER` are deliberately disjoint: policy authorship and gate approval must not be the same grant.

**Resource granularity: `org → project → repo`.** Roles bind at org or project. Repos inherit from their project; a repo may be *narrowed* but never widened. Graph nodes and edges are **not** a permission boundary — they inherit the repo they were extracted from, and a query returning nodes from N repos is filtered to the caller's repo set at the query layer. `INFERENCE` Per-node ACLs are the retrofit-expensive trap here; repo-derived inheritance is enforceable with one join and is what an auditor expects.

**Deferred to v2:** relationship-based authz (OpenFGA/Cedar). **Retrofit cost: low** — the v1 checks live behind one `can(actor, action, resource)` interface, so the engine swaps underneath. Deferring the `org_id` column, by contrast, is the expensive one, which is why it is not deferred.

---

## 3. Audit log — **non-repudiable + confidential; public verifiability becomes on-demand**

**The pick-two, answered.** Per `docs/spike/security.md` §2.5, Specera takes **non-repudiation and confidentiality**, and *forgoes continuous public verifiability*. Publishing to public Rekor is rejected outright: a Fulcio cert embeds the GitHub Actions OIDC subject containing the repository path, so the log becomes a live feed of a customer's private repo names and build cadence.

**Design (concrete).**

1. **Append-only in the database, enforced by the database.** `audit_event` table; the application role holds `INSERT` and `SELECT` only — `REVOKE UPDATE, DELETE, TRUNCATE`. No ORM-level convention. `FACT` Anti-pattern to avoid: `sourcebot/packages/backend/src/ee/auditLogPruner.ts` bulk-deletes audit rows in 10 000-row batches on a 24h timer driven by `SOURCEBOT_EE_AUDIT_RETENTION_DAYS`. That is Xray's mutable-history failure mode with a scheduler. **Specera ships no pruner.**
2. **Per-org hash chain.** Each row stores `prev_hash` and `entry_hash = H(prev_hash ‖ canonical(payload))`. Any deletion or edit breaks the chain at a detectable index. Chain head is per-org so tenants cannot interfere.
3. **Signed checkpoints.** Every N events / T minutes, a Merkle root over the segment is signed by a **customer-held KMS key Specera never possesses** (§2.5 requirement). Specera cannot forge a customer's history; a compromise of Specera does not forge anyone's.
4. **Anti-backdating without leakage.** The **root hash only** is submitted to an RFC 3161 TSA (`sigstore/timestamp-authority`, Apache-2.0, or any commercial TSA the customer already trusts). A root hash is a fixed-length digest — it names no repository, no branch, no artifact. This buys *existed-by-T* with zero confidentiality loss, which is exactly what a public Rekor entry cannot do.
5. **Selective disclosure.** To prove one event to an auditor, the customer discloses the event, its inclusion proof, the signed checkpoint, and the TSA token. The auditor verifies independently. Public verifiability is therefore *available on demand* rather than *continuous* — the honest way to describe what was traded.
6. **Immutability bar = Vera, not Xray.** `FACT` (`.spike/recheck-vera.md` §4) Vera's approved records are Read-Only / Delete Denied / Move Denied, and "revising the record… will cause a new revision to be created… and the revision number incremented." Specera mirrors this: an approved gate decision is never overwritten, only superseded by a new revision that links to its predecessor.
7. **Legal deletion vs append-only — state which wins.** `security.md` §4 demands this. **Redaction wins over retention, but never over the chain**: the payload cell is overwritten with a tombstone recording who ordered the redaction under what authority; `entry_hash` is unchanged because it was computed over the *original* payload, so the chain still verifies and the redaction is itself an audit event. Erasure is provable; history is not silently rewritten.
8. **Export.** Newline-delimited JSON + the checkpoint chain, streamed, no vendor format.

**Deferred to v2:** a real transparency log (`google/trillian`) for customers who want a private log with gossip. **Retrofit cost: low** — the Merkle checkpoint format from day one is what Trillian consumes.

---

## 4. Deployment — two tiers, and an honest answer on the single binary

**DECISION.** Ship in v1: a digest-pinned **Dockerfile**, a **`docker-compose.yml`**, and an **offline bundle** (`specera-airgap-<version>.tar` of all image tarballs + checksums + signatures). Ship in **v1.1**: a first-party **Helm chart**.

`FACT` Helm is the category's universal deferral: across all 19 clones, `find -name Chart.yaml` returns **zero results**. sourcebot — the closest analogue, with SSO, SCIM, audit and entitlements — ships Compose only. `INFERENCE` Compose-first is the correct sequencing, but Helm cannot slip to v2: it is the gate on the large-install tier, and Greptile documents both tiers (`greptileai/akupara`). Write the chart ourselves; `bitnami/charts` is `NOASSERTION` and moved behind a registry paywall in 2025 — depending on it for Postgres/Redis subcharts would break air-gapped installs.

**Single static binary — a dependency on S1, not an assumption.**

| If S1 chooses | Single static binary? | What we ship instead |
|---|---|---|
| Rust | **Yes** (`x86_64-unknown-linux-musl`) | True static binary; CLI ships this way |
| Go | **Yes** (`CGO_ENABLED=0`) | Same |
| TypeScript/Node | **No** | `FACT` codegraph's `BUNDLING.md` documents the honest ceiling: a *vendored Node runtime* archive per platform (`node` + `lib/dist` + `bin/` launcher, 6 targets), enabled by `node:sqlite` removing native addons. That is a self-contained bundle, **not** a single binary — say so in the docs rather than overclaiming |
| Python | **No** | Container only; PyInstaller/`uv` bundles are not credible for a server |

**S5's position:** the *CLI* must be a single-file download in all four cases (bundle or binary); the *server* is a container in all four. Do not block on the binary question — it changes the CLI's packaging, nothing architectural.

**Air-gapped rules (non-negotiable, all four are direct anti-patterns observed in the clones).**
- Base images pinned by **digest**, never tag. `FACT` `sourcebot/docker-compose.yml` uses `image: …/sourcebot:latest` with `pull_policy: always` — unreproducible and impossible air-gapped.
- **No `npx -y …@latest`** anywhere in runtime, install, or MCP config. `FACT` (`.spike/findings-supply-chain.md:43`) `GitNexus/.mcp.json` declares `npx -y gitnexus@latest mcp` — fetch-and-execute of whatever is published at run time.
- **No build-time SaaS coupling.** `FACT` `sourcebot/Dockerfile` bakes `NEXT_PUBLIC_SENTRY_*` and `NEXT_PUBLIC_LANGFUSE_*` into the image at build. Specera's observability endpoints are runtime config, unset by default.
- **Offline licence.** Signed licence assertion (Ed25519 JWT) verified against a public key **embedded in the image**, expiry inside the token, no network. `FACT` sourcebot has the embedded-key half (`Dockerfile:154 ENV SOURCEBOT_PUBLIC_KEY_PATH=/app/public.pem`) but pairs it with online "Lighthouse" sync (`License.licenseAssertion`, `lastSyncAt`, `ServicePingEvent`). Take the first half, reject the second.
- Every image, chart, and bundle is cosign-signed with an SBOM; the air-gap tarball is verifiable with no registry reachable.

---

## 5. Secrets and credential handling

**Minimum scopes (v1).** GitHub App: `contents:read` on governed repos, `pull_requests:read`, `checks:write`. **Never** `contents:write`, never org-wide read in v1, and **never a branch-protection bypass actor** (`security.md` §3 — GitHub's own agent requires it, which *weakens* the control set; matching that is a regression). Jira: `read:jira-work` only — **`write:jira-work` is dropped from v1** entirely, matching §3's "earn the scope later".

**`checks:write` is a production-control capability.** It can block or unblock every merge in the org. Consequences, treated like a deploy credential: separate credential from the read path; issued only to a `SERVICE` principal bound to one project; every use written to the audit chain with the run id; rotation on a fixed schedule with overlap; **kill-switch that degrades the gate to advisory** rather than failing merges org-wide.

**At rest.** Envelope encryption: per-tenant DEK, wrapped by a KEK from env/file (v1) or OpenBao/cloud KMS (optional). **AES-256-GCM everywhere.** `FACT` Do not copy sourcebot: `packages/shared/src/crypto.ts:9` uses `aes-256-cbc` for the general `encrypt()` path — unauthenticated and malleable — and reserves GCM only for OAuth tokens (`:146`). One algorithm, authenticated, no exceptions. `FACT` Also do not copy `Buffer.from(env.SOURCEBOT_ENCRYPTION_KEY, 'ascii')` — a raw 32-char env string used directly as key material, no KDF.

**Rotation.** KEK rotatable without re-encrypting data (rewrap DEKs). Provider tokens re-mintable per install; the GitHub App private key is the true blast radius — HSM/KMS custody, never in an env var, never in the image.

**On leak.** Documented, testable runbook: revoke the App installation (invalidates all derived tokens), rewrap, force re-auth of all sessions, then **replay the audit chain over the exposure window to enumerate exactly which gates the credential touched** — the hash chain is what makes the blast-radius answer credible rather than a guess.

---

## 6. Data residency and no-training — what must be architecturally true

`FACT` The bar to beat: Greptile trains on customer data by default with opt-out and caches code until access revocation; Devin trains by default with no air-gapped option (`security.md` §4).

For "no egress by default" to be **defensible rather than a promise**, all six must hold:

1. **No network on the ingestion path.** Enforced by the sandbox (deny-by-default egress), not by code review. Analysis runs with zero outbound.
2. **BYO-LLM, no default provider.** Specera ships with no inference endpoint configured. A fresh install that reaches a model vendor is a bug, not a setting.
3. **Ephemeral clones with an explicit TTL**, not "cached until revocation".
4. **Telemetry is opt-in and off by default.** `FACT` Both references get this wrong for our positioning: sourcebot's `SOURCEBOT_TELEMETRY_DISABLED` **defaults to `'false'`** (`packages/shared/src/env.server.ts:431`) — phone-home on by default; codegraph's `TELEMETRY.md` is default-on with an opt-out. `INFERENCE` Opt-out telemetry and "no egress by default" are not simultaneously true; shipping both is the claim collapsing. **Acceptable if and only if the operator explicitly enables it:** version string, install id, coarse feature counts. **Never acceptable at any setting:** repo names, file paths, identifiers, query text, graph content, error payloads containing user data. Honour `DO_NOT_TRACK=1` (codegraph does; adopt it), and — the differentiator — make the telemetry payload schema an **allowlist enforced at the emit site and printable via `specera telemetry show`**, so the claim is inspectable rather than trusted.
5. **No update check by default** either. A daily version poll is egress; air-gapped installs must not attempt it.
6. **Residency is a non-question by construction.** With 1–5, data never leaves the customer's infrastructure, so there is no region to choose. This is the whole argument, and it is only worth making if 1–5 are true.

**No training on customer data, stated first-party, with no toggle.** Costs nothing technically and forecloses a data asset the category assumes — that is the trade, made deliberately.

---

## 7. Compliance surface — only what is expensive to retrofit

| Do from day one (architectural) | Why it cannot wait |
|---|---|
| `org_id` + RLS on every table | §2 — a rewrite of every query later |
| Append-only audit chain, DB-enforced, no pruner | §3 — you cannot retroactively prove history you already allowed to be edited |
| Every mutating action emits an audit event via **one** chokepoint | Bolting events onto scattered call sites later never reaches full coverage, and partial coverage fails the control |
| Actor identity on every event (user / service / CI), never "system" | An unattributable event is a failed access-review evidence request |
| Separation of duties in the role model (`ADMIN` ≠ `APPROVER`) | Splitting a merged role later invalidates every existing grant |
| Encryption at rest with **rotatable** KEK | Retrofitting rotation means a migration over all ciphertext |
| Backup **and a tested restore** of Postgres + the chain head | Restore that breaks the hash chain destroys the audit property — must be designed with it |
| Signed, versioned releases with SBOM | Change-management evidence is reconstructed from CI; retrofitting provenance to shipped versions is impossible |
| Deterministic, reversible schema migrations | Change management on the data layer |

| Can wait (programme, not architecture) | Retrofit cost |
|---|---|
| Access-review *UI* (the data already exists — `lastActiveAt` per membership, as sourcebot models at `schema.prisma`) | Low |
| Policy documents, vendor register, training, pen-test cadence | None architectural |
| SCIM deprovisioning | Medium — Polis provides it; wiring is a feature |
| SIEM streaming (Splunk/Sentinel) | Low — the NDJSON export is the source |
| FedRAMP/HIPAA-specific controls | High, but only if that market is chosen |

Everything in the second table is a decision to defer. Everything in the first is a decision that gets made on day one whether or not it is made deliberately.

---

## Summary

**Top recommendation per area.** Auth: app is an OIDC RP only; **Ory Polis** (Apache-2.0, 2026-07-27, not archived) as a SAML/SCIM bridge container; runner-up **Keycloak**; WorkOS rejected as incompatible with self-host. Tenancy: **multi-tenant schema, single-tenant deployment**, six roles with `ADMIN`/`APPROVER` disjoint, granularity `org → project → repo` with graph inheriting repo. Audit: DB-enforced append-only + per-org hash chain + customer-KMS-signed Merkle checkpoints + RFC 3161 timestamp **over the root hash only** — non-repudiable and confidential, public verifiability by selective disclosure; no pruner, ever. Deployment: digest-pinned Dockerfile + Compose + air-gap tarball in v1, first-party Helm in v1.1; single static binary **conditional on S1** (yes for Rust/Go, no for Node/Python — CLI ships as one file either way). Secrets: AES-256-GCM envelope encryption, no `contents:write`, no `write:jira-work`, no bypass actor, `checks:write` governed as a production control. Egress: opt-in telemetry with a printable allowlist, BYO-LLM with no default endpoint, no update check.

**Biggest risk.** Ory Polis is the only load-bearing dependency I cannot fully de-risk: no release since `v26.2.0` (2026-03-20) despite pushes to 2026-07-27, and the commit stream is ~80% bot. If Ory shelves it, SAML — a procurement gate — goes with it. The OIDC-inward boundary is deliberately the mitigation: Keycloak brokering is a container swap, not a code migration. `INFERENCE` This is why I would not embed a SAML library in-process in any language.

**Could not verify.** (a) Whether Ory has published a support/EOL commitment for Polis — nothing in the repo says. (b) Whether Greptile's Jackson usage predates the Ory transfer (their docs are the only source and I could not fetch them here). (c) Whether the brief's "sourcebot uses Jackson" was true of an earlier version — the full 1358-commit history contains no `jackson` or `saml` string at all, so if it was ever true it left no trace in this repository. (d) S1's language choice, on which the single-binary row and the Auth.js line depend — stated as a dependency, not assumed.
