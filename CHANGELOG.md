# Changelog

This document preserves release-specific changes, verification notes and compatibility information for Testudo. For current functionality, installation and everyday usage, see the [README](README.md) and the [User Manual](Testudo_manual.pdf).

---

## Testudo 0.3.2 (build 18)

Testudo 0.3.2 is a maintenance release focused on Task navigation and archive visibility.

### Archived Task visibility

- Closed top-level Tasks and their descendants are excluded from active Task status lists.
- Archived Tasks are excluded from the All Tasks collection and its count.
- Parent Task selectors for Tasks, Notes and Activities show active Tasks only.
- Existing Parent relationships inside archived Task trees remain preserved.
- Archived Tasks remain accessible in Archive and historical relationship contexts.
- Reopening a Closed top-level Task restores its descendants to the active workflow using their retained statuses.

### Discontinued Task navigation

- Selecting a Discontinued Task in the middle column now opens its detail page.
- The detail page exposes the normal metadata, relationships, history and applicable editing and deletion controls.
- Discontinued remains a Task workflow status, distinct from the Closed archive lifecycle.

### Verification and compatibility

The development build passed 111 automated tests: 75 core tests and 36 integration tests, including a new archived-task visibility regression test.

This release introduces no new Environment database schema and requires no additional data migration. The compatibility rules introduced with Planned Start in Testudo 0.3.1 remain applicable.

---

## Testudo 0.3.1 (build 17)

This version introduces optional, timezone-aware Planned Start for Tasks.

Planned Start is distinct from the actual Started timestamp, Deadline,
and workflow status. Subtasks inherit availability constraints from
their Parent Tasks.

The feature is integrated into the existing editor, Today, Calendar,
Day workspace, Task details and History.

The implementation passed 110 automated tests and manual UI checks.

**Important compatibility notice:** Work Environments using Planned
Start are upgraded to database schema 9. Testudo 0.3.0 cannot open
schema 9 Environments. Update all Macs using the same Environment
before introducing Planned Start data.



---

## Testudo 0.3.0 (build 16)

Testudo 0.3.0 established the Environment compatibility safeguards described below.

### What changed in 0.3.0

Testudo 0.3.0 strengthens Work Environment storage safety and establishes a more explicit foundation for format compatibility.

The release introduces a separate TestudoCore module for Environment format inspection, compatibility decisions, JSON encoding and decoding, manifest handling, startup validation, and snapshot-write preflight checks.

### Safer Environment activation

Before opening or switching Work Environments, Testudo verifies the relevant storage format and Environment identity.

The application rejects unsupported formats and incompatible or damaged data rather than silently replacing or rewriting them.

Environment switching also protects the currently active Environment when saving its pending changes or updating the local registry fails.

### Credential Store protection

Environment credential changes now include additional safeguards:

- existing credential files must be readable and compatible;
- the stored Environment identity must match the active Environment;
- unsupported credential schemas are rejected;
- existing memberships cannot silently disappear during a credential update;
- a missing credential file is not silently recreated by the normal password writer;
- Administrator password changes require an open Environment session.

The normal creation of an Environment and its initial Administrator remains supported.

### Compatibility and migration policy

Testudo 0.3.0 does not automatically migrate legacy Environment databases from schema 7 to schema 8.

Existing compatible schema 8 Environments remain supported, subject to the normal compatibility checks.

The obsolete automatic schema 7-to-8 migration implementation has been removed. Environments requiring migration must be handled separately, with appropriate backups and an explicitly verified migration procedure.

Journal-based Environment storage requires a different storage engine and is not enabled by this release.

### Verification

The 0.3.0 development baseline passed 95 automated tests: 69 TestudoCore tests and 26 integration tests.

The integration coverage includes Environment startup, registration, activation, switching, failure recovery and credential-file safety.

### Synchronization limitations

Portable Work Environments can still be stored in folders synchronized by Dropbox, iCloud Drive, OneDrive or other filesystem providers.

This release does not introduce simultaneous multi-device editing, automatic conflict resolution or a synchronization server.

Avoid editing the same Environment concurrently on multiple Macs, and keep independent backups.
