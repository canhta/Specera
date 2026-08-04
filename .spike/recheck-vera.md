# Reopening check 1 — Vera: auditable vs. independently verifiable

All fetches 2026-08-04. Sources: docs.tricentis.com (Vera 2026.1 / vera-latest),
documentation.tricentis.com (qTest), tricentis.com.

## Correction to decision.md §2.1 — Vera does hash, it is not a naive audit log

`FACT` Vera's server has a **Signatures** module that "Applies 21 CFR Part 11
complaint [sic] signature and hash", and a separate **Verification** module that
"Verif[ies] records and signatures against record and signature hash". The
Records Management Policy defines "Data fields to be hashed with Vera signature".
Record types carry an `"Allow Verify Signatures": true` flag.
(https://docs.tricentis.com/vera-2026.1/content/admin_guide/technical_architecture_specification.htm;
https://docs.tricentis.com/vera-latest/content/admin_guide/administration/configure_record_management_policy.htm)

`FACT` Storage is MongoDB: "NoSql, Document Database stores records, signatures,
approval routes, users and approval roles." (same architecture page)

§2.1 credited Vera with "auditable electronic records". It actually ships
hash-based integrity checking. That is stronger than the no-go assumed — and it
is still not third-party verifiability. The five questions:

## 1. Cryptographically verifiable by a non-trusting third party?

`FACT` The only documented verification path is **inside Vera, admin-only**:
"Vera administrator users can view signatures that failed verification" via a
scheduled scan (Last Scan / Next Scan) with a per-signature "Re-verify" icon in
the Vera Web Portal Administration area.
(https://docs.tricentis.com/vera-2026.1/content/admin_guide/administration/signature_verification_failure_report.htm)

`UNVERIFIED` No hash algorithm, key custody model, signing-key ownership,
published verification procedure, or attestation format appears anywhere in the
Vera documentation set (architecture spec, admin guide, user guide, config
guide, qTest integration guide — all read). **What would settle it:** a Vera
security/validation whitepaper or SOP naming the algorithm and key holder, or a
customer-runnable verification tool/API. Do not read this as proof of absence —
read it as: nothing buyer-visible claims third-party verifiability.

`VENDOR CLAIM` / do-not-conflate: "Vera connections support PFX-formatted
certificates and passwords, enabling secure, encrypted communication with
on-premises systems and API gateways" (tricentis.com blog, Vera 2024.3). That is
**transport** security, not record signing. It is not evidence for Q1.

## 2. Or append-only inside Tricentis?

`INFERENCE` Effectively yes, with a hash self-check. The hashes exist and are
checked — but the checker is the vendor's own service, the result is visible only
to Vera admins, and the hashes are stored in the same MongoDB as the records. An
auditor who does not trust Tricentis has no documented way to run the check
themselves.

## 3. Exportable in a form verifiable outside the product?

`FACT` Export is a **Print View (Record Detail Report)** with "an option to print
or save to PDF", containing a Signatures section (approval levels, statuses,
approval dates), a generation timestamp, page numbers, and a URL back to the Vera
record. The documented contents include **no hash, checksum, or certificate**.
(https://docs.tricentis.com/vera-2026.1/content/user_guide/web_portal/view_record_detail.htm)

`FACT` On the qTest side, exported VERA data is status metadata only — "VERA ID",
"VERA Approval Status", "VERA Pending Tasks", "VERA Approval Route", "VERA
Rejection Reason" — "available in the Test Run Data Query and the Test Run Export
Reports".
(https://documentation.tricentis.com/qtest/1001/en/content/qtest_manager/integrations/vera_integration.htm)

`UNVERIFIED` Whether the exported PDF is digitally signed (PAdES or similar).
Nothing says it is; nothing says it isn't. **What would settle it:** one exported
Record Detail Report PDF, checked for a signature dictionary.

## 4. Who can modify or delete signed records?

`FACT` Materially tighter than Xray. Records "can only be deleted while in the
first workflow state"; the workflow "does not allow records to transition back to
the first workflow state once they have entered another state"; and the Jira
workflow marks Routing-for-Approval / Rejected / Approved states **Read-Only,
Delete Denied, Move Denied**. Only the Vera Service Account role may execute the
Complete Approval / Complete Rejection transitions.
(delete_jira_records.htm; technical_architecture_specification.htm)

`FACT` Editing an approved record does not overwrite it: "Revising the record in
Jira will cause a new revision of the record to be created in Vera and the
revision number to be incremented." (revise_jira_records.htm)

`UNVERIFIED` Whether a Vera system administrator — or anyone with direct MongoDB
access, which the **customer** has in the on-prem deployment ("VERA Server
Installation Directory", editable JSON policy files) — can alter stored records or
signatures, and whether the Verification scan would catch it. **What would settle
it:** the Vera validation/SOP package or a documented DB-tamper test result.

## 5. What does the signature bind to?

`FACT` **Record ids and versions, never a build artifact.** The documented
captured fields are: qTest Project ID, "qTest Version ID", "Test Case Version",
Execution Log Name, execution statuses, start/end timestamps, Tester; Jira Issue
Type / Summary / Description; plus a Vera-managed integer `Revision`. No commit
SHA, build number, container digest, or artifact hash appears anywhere in the
field list. (view_record_detail.htm; route_test_run_for_approval_qtest.htm)

`INFERENCE` The hash therefore covers *the text Vera imported from Jira/qTest*,
not the software under test. It attests that a record was signed and has not
changed since — not that a specific build was the thing approved.

## Verdict

**REOPEN** — narrowly. Vera's hashing is real and Q4 is genuinely strong, but the
only documented verification is an admin-only scan inside the vendor's own
portal, exports carry no cryptographic material, and `FACT` the signature binds to
record ids and versions with no commit/build/artifact digest anywhere — so
independently verifiable attestation *bound to a build* remains unoccupied, and
the §5.1 reopening condition is met.

Caveat for the coordinator: Q1 and Q3 resolve as `UNVERIFIED`, not as proven
absence. The reopen rests on Q5, which is FACT-grade and independent of the
crypto question. If a Vera validation whitepaper later shows a published
verification procedure, only Q5 survives — and Q5 alone is a feature, not a
company, which is §2.1's original objection.
