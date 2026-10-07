# Testudo

<p align="center">
  <img src="Sources/Testudo/Resources/TestudoIcon.png" alt="Testudo application icon" width="180">
</p>

<p align="center">
  <strong>A native, local-first macOS environment for structured professional and research work.</strong>
</p>

<p align="center">
  <strong>Testudo 0.2.2 · build 15 · macOS 26+ · Apple Silicon · Swift 6+ · MIT</strong>
</p>

---

Testudo is a native macOS application for organising work that is too interconnected for a conventional task list.

It combines:

- hierarchical Tasks, Notes and Activities;
- professional context through People, Groups and Organizations;
- Themes and multi-Theme classification;
- chronological work history;
- calendar information;
- semantic relationships;
- time-zone-aware dates;
- portable local Work Environments.

Testudo is designed particularly for research, scientific software, laboratories, technical operations, academic collaboration, infrastructure, committees, long-running projects and other professional work where both **structure** and **history** matter.

The application is local-first. It does not require a Testudo cloud service.

---

## Current release

The current version is:

```text
Testudo 0.2.2
Build 15
```

### What changed in 0.2.2

Testudo 0.2.2 refines active Work navigation and introduces the first Beta version of document export.

#### Active All Tasks

Closed top-level Tasks and the Work contained inside their archived subtree are no longer shown in the active All Tasks collection.

Closed Work remains available through Archive and retains its actual workflow status and history.

#### Calendar detail destination

Choosing Calendar now presents the currently selected Day in the right-hand detail pane.

The initial selected date is Today. When another date has been selected, Testudo preserves that date when returning to the Calendar rather than unnecessarily resetting the Calendar workflow.

#### Export — Beta

File → Export… introduces an early Beta document-export workflow.

The current exporter produces PDF documents from semantic Testudo data rather than screenshots of the interface. PDF text is therefore selectable and remains sharp when scaled.

For Tasks, the exporter can optionally include nested Work recursively. When nested Work is enabled, the user can select the expansion depth up to the actual maximum depth of the selected Task subtree.

The exported document currently reproduces important parts of Testudo's detail visual language, including titles, SF Symbols, metadata, Work status, Theme context and structured detail rows.

The detailed application Work Log is intentionally excluded from exported documents.

Export remains a Beta feature. Document layout and visual fidelity do not yet reproduce every element of every Testudo detail pane exactly and will continue to evolve in later releases.

No Work Environment schema migration is required for this release.

---

## Requirements

The current source targets:

- **macOS 26 or later**
- **Apple Silicon**
- an Apple developer toolchain providing **Swift 6 or later**
- Git

Testudo is a native Swift / SwiftUI application and is currently distributed through a **source-first local build workflow**.

The application is compiled directly on the Mac where it will run.

No prebuilt Testudo executable is required, and the current local build workflow uses ad-hoc signing rather than requiring membership in the paid Apple Developer Program.

---

## Installation

### Quick installation

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/foivoskar/Testudo/main/install.sh | bash
```

The installer:

1. checks the Mac and Apple developer toolchain;
2. clones or safely updates the public Testudo repository;
3. refuses to overwrite a source checkout containing local modifications;
4. builds Testudo locally;
5. signs the application locally;
6. creates and verifies a DMG installer;
7. opens the finished installer.

When the DMG opens, drag `Testudo.app` into `Applications`.

The default source checkout is:

```text
~/Testudo
```

### Check compatibility without installing

```bash
curl -fsSL https://raw.githubusercontent.com/foivoskar/Testudo/main/install.sh | bash -s -- --check
```

### Inspect the installer first

```bash
curl -fsSL \
  https://raw.githubusercontent.com/foivoskar/Testudo/main/install.sh \
  -o testudo-install.sh
```

Inspect the script, then run:

```bash
bash testudo-install.sh
```

### Manual build

```bash
git clone https://github.com/foivoskar/Testudo.git
cd Testudo
./Scripts/build-local-dmg.sh
```

The resulting installer is written to `dist/`, for example:

```text
dist/Testudo-0.2.2-macOS-arm64.dmg
```

### Updating

For an installation created with the quick installer, run the installation command again.

For a manual checkout:

```bash
cd ~/Testudo
git pull --ff-only
./Scripts/build-local-dmg.sh
```

Then replace the previous application in `/Applications` with the newly built version.

---

## Work model

Testudo separates work into three object types:

### Task

An actionable item that has workflow status and may contain further work.

### Note

Durable information or context that does not require Task status.

### Activity

A chronological record of something that happened.

Examples include:

- a discussion;
- a decision;
- a measurement;
- an intervention;
- a review;
- a completed action;
- a resolved problem.

Activities are work-log objects, not scheduled calendar objects.

```text
Activity       = something recorded as having happened
Calendar Event = something represented in the calendar
```

---

## Task hierarchy

Tasks can contain child work.

A Task may contain:

- sub-tasks;
- Notes;
- Activities.

Sub-tasks can themselves contain further work, so the hierarchy can continue to arbitrary depth.

The hierarchy is independent from Theme classification, organizational structure and chronology.

---

## Task lifecycle

The normal workflow states are:

```text
To Do
  ↓
In Progress
  ↓
Completed
```

or, when work ends without successful completion:

```text
To Do / In Progress
        ↓
   Discontinued
```

### Completed

`Completed` means the work was successfully completed.

The completion timestamp is retained independently from the Task's creation and start dates.

### Discontinued

`Discontinued` means the work ended without being considered successfully completed.

The Task retains:

- the discontinuation timestamp;
- the reason;
- an optional outcome or explanatory note.

Discontinuation is deliberately different from deletion: the Task remains part of the historical record.

### Closing and Archive

Closing is separate from workflow status.

Only a **top-level Task** can be Closed, and only after it is:

- Completed; or
- Discontinued.

A Closed Task is moved to Archive together with its descendants.

The Task still remains, for example:

```text
Status: Completed
Archive lifecycle: Closed
```

or:

```text
Status: Discontinued
Archive lifecycle: Closed
```

The normal open state is implicit and is not shown as a separate status.

### Reopening

A Closed top-level Task can be Reopened.

Reopening:

- removes it from Archive;
- restores its Task tree to the normal workflow views;
- preserves its actual workflow status;
- preserves previous lifecycle history.

Close and Reopen operations are themselves recorded in history.

---

## History

Testudo is designed to preserve not only the current state of work but also how that state was reached.

History events include, where relevant:

- Created
- Edited
- Status changed
- Scheduled
- Started
- Completed
- Discontinued
- Closed
- Reopened
- Activity logged
- Relationship added
- Relationship removed
- Moved

Historical lifecycle information remains distinct from the current state.

This makes it possible, for example, to discontinue a Task, reopen it into active work later, and still retain the earlier discontinuation in its historical record.

---

## Interface

Testudo uses a native three-column macOS layout:

1. **Sidebar** — global navigation
2. **Middle column** — the selected collection or hierarchy
3. **Detail pane** — the currently selected object or editor

The sidebar currently contains:

- New Entry
- Today
- Calendar
- All Tasks
- To Do
- In Progress
- Completed
- Discontinued
- Archive
- Timeline
- Themes
- Organizations
- Groups
- People

---

## Browser-style detail navigation

The right pane keeps browser-style navigation history.

It supports:

- Back;
- Forward;
- two-finger trackpad navigation.

Navigation history is synchronized with the rest of the interface.

Moving Back or Forward restores the corresponding:

- sidebar section;
- middle-column selection;
- right-pane content.

Archived Tasks participate in the same navigation history as active work.

References inside detail views are navigable where appropriate, allowing movement between Work items, Themes, People, Groups, Organizations and Calendar Events.

---

## New Entry and editing

`New Entry` is the global Work creation action.

Keyboard shortcut:

```text
Command-N
```

It can create:

- Task
- Note
- Activity

The editor exposes the fields relevant to the selected Work type, including:

- title and description;
- Themes;
- Parent Task;
- Task status;
- lifecycle dates;
- reminders;
- time zones;
- semantic relationships.

The same full Work editor is used when editing an existing Task, Note or Activity.

Normal detail pages remain primarily read-only and expose one whole-object **Edit** action.

---

## Today

Today combines work that is relevant to the current day through chronology rather than acting as a simple scheduled-task list.

Its data can include work associated with current-day lifecycle and activity events such as:

- creation;
- start;
- completion;
- discontinuation;
- logged Activity.

---

## Day workspace

Selecting a Calendar date opens a dedicated Day workspace in the detail pane.

The workspace combines Schedule, Planned Work, Due & Reminders, Day History and a collapsible App Log.

Planned Work is calculated from the current Work state. Today can surface overdue Tasks, while future days do not inherit Tasks whose deadlines have already passed merely because they remain open.

Day History represents real Work chronology rather than application editing chronology.

Read-only dates elsewhere in Testudo can navigate directly to the corresponding Day page.

---

## Themes

Themes provide semantic classification independently from the Work hierarchy.

Themes can themselves be hierarchical.

A Work item can belong to multiple Themes.

This allows one Task, Note or Activity to participate in several conceptual areas without duplication.

### Descendant aggregation

Related Work for a parent Theme can include Work belonging to descendant Themes.

For example:

```text
Theme A
└── Theme B
    └── Theme C
```

Work directly associated with Theme C can also appear when viewing related Work for Theme B and Theme A.

This does not silently rewrite the Work item's direct Theme membership.

---

## People, Groups and Organizations

Testudo maintains a professional entity model separate from the Work hierarchy.

Supported entity types are:

- Person
- Group
- Organization

Organizations can contain other Organizations.

Groups can represent, for example:

- laboratories;
- teams;
- committees;
- collaborations;
- working groups.

People can have multiple affiliations, including a primary affiliation.

This structure allows professional context to be represented independently from the Task hierarchy.

---

## Work relationships

Work can be related semantically to People, Groups and Organizations.

Available relationship roles are:

- For
- Requested by
- With
- Assigned to
- Related to

Relationships may be marked as inherited by child work.

This allows a parent Task to provide useful professional context to descendants while each child remains independently editable.

---

## Related Work

Themes, People, Organizations and Groups can expose the Work connected to them.

Related Work can include:

- Tasks;
- Notes;
- Activities.

Aggregation can follow relevant descendant structures, while duplicate Work items are suppressed when several paths resolve to the same object.

---

## Calendar

Calendar Events are separate objects from Activities.

Testudo supports:

- Testudo Calendar Events;
- Apple Calendar / EventKit integration;
- iCal subscriptions;
- links between Calendar Events and Testudo Work.

External calendar information may be read-only depending on its source.

---

## Time zones

Testudo treats absolute timestamps and their source time zones separately.

The application stores IANA time-zone identifiers where relevant for dates such as:

- Created
- Updated
- Scheduled
- Deadline
- Reminder
- Started
- Completed
- Discontinued
- Closed
- Activity occurrence

The device time zone is used as the normal display context.

This allows the same absolute instant to remain correct even when the Mac later moves to another time zone.

---

## Work Environments

Testudo supports multiple independent **Work Environments**.

Each Environment is stored as a portable `.testudoenv` package.

A typical Environment contains:

```text
Example.testudoenv/
├── EnvironmentManifest.json
├── EnvironmentData.json
├── EnvironmentCredentials.json
└── EnvironmentIcon.png
```

The icon is optional.

A Work Environment can be stored locally or in a filesystem location synchronized through services such as:

- Dropbox;
- iCloud Drive;
- OneDrive;
- another macOS-accessible filesystem provider.

Testudo works directly with the Environment package rather than importing its contents into a mandatory central cloud service.

Filesystem synchronization should still be treated as filesystem synchronization: avoid simultaneous conflicting edits to the same Environment package from multiple computers.

---

## Local-first design

Testudo does not require a Testudo server or hosted Testudo account.

Work Environment data remains inside the selected `.testudoenv` package.

Application-level information such as:

- the local Testudo profile;
- registered Environment locations;
- local authentication state

is stored separately.

This keeps Work Environment data portable, independently back-upable and suitable for user-controlled storage.

---

## Identity and authentication

Testudo has two distinct identity layers.

### Local Testudo user

The installation has a local profile and application authentication.

Current functionality includes:

- password management;
- security-question password recovery;
- portable `.testudouser` profile export/import;
- Log Out;
- complete local Sign Out.

### Work Environment membership

Each Work Environment has its own membership and authentication context.

Environment membership is independent from the installation-level local user profile.

Environment Administrators can manage supported membership and password-administration operations within the Environment.

---

## Demo Environment

Testudo can generate a complete fictional Demo Environment.

The Demo contains interconnected examples of:

- People;
- Organizations;
- Groups;
- Themes;
- Tasks and sub-tasks;
- Notes;
- Activities;
- Calendar Events;
- affiliations;
- Work relationships;
- Task lifecycle;
- chronology and history;
- archived work.

Demo dates are generated relative to the date on which the Environment is created.

---

## Building from source

Version and build identity are defined centrally in:

```text
Scripts/version.sh
```

### Build the application

```bash
./Scripts/build-app.sh
```

The application bundle is created at:

```text
dist/Testudo.app
```

### Build a release DMG

```bash
./Scripts/build-release.sh
```

### Build and verify a local installer

```bash
./Scripts/build-local-dmg.sh
```

The build scripts deliberately use the Apple Swift toolchain selected through `xcrun`.

SwiftPM uses its current default build system.

---

## Repository structure

The main source tree is organised as:

```text
Sources/Testudo/
├── Auth/
├── Demo/
├── Models/
├── Resources/
├── Store/
├── Time/
├── Views/
└── TestudoApp.swift
```

Other important repository paths include:

```text
Scripts/                         build and release tooling
Documentation/TestudoManual/    LaTeX manual source
Docs/                            project specifications
install.sh                       source-first installer
Testudo_manual.pdf               bundled user manual
```

---

## Documentation

The repository contains:

- [Testudo User Manual — PDF](Testudo_manual.pdf)
- [LaTeX manual source](Documentation/TestudoManual/Testudo_manual.tex)
- [LaTeX manual class](Documentation/TestudoManual/testudomanual.cls)
- [Manual build script](Scripts/build-manual.sh)

The bundled **Testudo User Manual 2.0 documents Testudo 0.2.2 (build 15)**.

Rebuild the bundled PDF from its LaTeX source with `./Scripts/build-manual.sh`.

This README and the User Manual reflect the current **Testudo 0.2.2 (build 15)** application state.

---

## Development status

Testudo is an early public release and remains under active development.

The interface and data model may continue to evolve between early versions.

Users should keep independent backups of important `.testudoenv` packages, particularly when moving between versions.

Backward compatibility is considered explicitly. Testudo 0.1.7 introduced migration handling for the pre-0.1.7 representation of Closed Tasks, and that compatibility remains part of the current application.

---

## License

Testudo is released under the **MIT License**.

See [`LICENSE`](LICENSE).

---

## Author

**Foivos Karakostas**
