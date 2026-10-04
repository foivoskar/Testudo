# Testudo

<p align="center">
  <img src="Sources/Testudo/Resources/TestudoIcon.png" alt="Testudo application icon" width="180">
</p>

<p align="center">
  <strong>A native, local-first macOS environment for structured professional and research work.</strong>
</p>

Testudo combines work management, professional context, organizational structure, calendar information, chronology, and portable local storage in one native macOS application.

It is intended for work that cannot be represented well by a flat task list: scientific research, research software engineering, academic collaboration, technical operations, laboratories, infrastructure, multi-institution projects, committees, and other long-running professional activity.

**Current documented version: Testudo 0.1.6 (build 7).**

---

## Requirements

The current Testudo source targets the modern Apple development platform.

Required:

- **macOS 26 or later**
- **Apple Silicon Mac**
- **Xcode 27** or an equivalent Apple developer toolchain
- **Apple Swift 6.4 or later**
- Git

Older macOS and Xcode versions are not maintained as compatibility targets for the current source tree.

Testudo uses current native SwiftUI functionality, including the modern macOS Liquid Glass interface.

---

## Installation

Testudo currently uses a **source-first local installation model**.

The application is compiled directly on the Mac where it will be used. A prebuilt Testudo executable is not required, and the current local-build workflow does not require membership in the paid Apple Developer Program.

Before installing, update macOS and Xcode to the supported versions above.

### Quick installation

```bash
curl -fsSL https://raw.githubusercontent.com/foivoskar/Testudo/main/install.sh | bash
```

The installer obtains the public source code, builds Testudo locally, ad-hoc signs the resulting application, creates a local installer DMG, verifies it, and opens the finished installer.

When the DMG opens, drag `Testudo.app` into `Applications`.

The default source checkout is:

```text
~/Testudo
```

The installer deliberately refuses to overwrite a source checkout that contains local modifications.

### Inspect the installer first

```bash
curl -fsSL \
  https://raw.githubusercontent.com/foivoskar/Testudo/main/install.sh \
  -o testudo-install.sh
```

Then inspect the file and run:

```bash
bash testudo-install.sh
```

### Manual build

```bash
git clone https://github.com/foivoskar/Testudo.git
cd Testudo
./Scripts/build-local-dmg.sh
```

The resulting installer is written to `dist/`, normally as:

```text
dist/Testudo-0.1.6-macOS-arm64.dmg
```

### Updating

For an installation made with the quick installer, run the same installation command again.

For a manual checkout:

```bash
cd ~/Testudo
git pull --ff-only
./Scripts/build-local-dmg.sh
```

Replace the older application in `/Applications` with the newly built copy.

---

## Core model

Testudo connects several domains that are often split across unrelated applications:

- Tasks and arbitrarily nested sub-tasks
- Notes
- Activities and work history
- Calendar Events
- Themes and sub-themes
- People
- Groups
- Organizations
- professional affiliations
- semantic Work relationships
- time-zone-aware dates
- independent portable Work Environments

The purpose is not only to record what must be done. Testudo also preserves **what happened, who or what the work concerned, where it belongs conceptually, and how it evolved over time**.

---

## Work Environments

Testudo supports multiple independent **Work Environments**.

Each Environment is stored as a portable `.testudoenv` package. A typical package contains:

```text
Example.testudoenv/
├── EnvironmentManifest.json
├── EnvironmentData.json
├── EnvironmentCredentials.json
└── EnvironmentIcon.png
```

The icon is optional.

A Work Environment may be stored locally or in a filesystem location synchronized through Dropbox, iCloud Drive, OneDrive, or another provider available to macOS.

Testudo works directly with the Environment package rather than importing it into a required central cloud service.

Cloud-synchronized storage should still be treated as filesystem synchronization. Avoid simultaneous conflicting edits from several computers.

---

## Local-first design

Testudo does not require a Testudo cloud service.

Environment data remains inside the selected `.testudoenv` package.

Application-level information such as the local Testudo profile, registered Environment locations, and local authentication state is stored separately.

This separation keeps Work Environment data portable and independently back-upable.

---

## Interface

Testudo uses a native three-column macOS interface:

1. **left sidebar** — global navigation
2. **middle column** — lists, hierarchies and collections
3. **right pane** — creation and detail views

The sidebar contains:

- New Entry
- Today
- Calendar
- All Tasks
- To Do
- In Progress
- Completed
- Archive
- Timeline
- Themes
- Organizations
- Groups
- People

### Sidebar visibility

The native macOS sidebar control hides and restores the first column.

When the sidebar is visible, the control belongs to the upper-right area of the sidebar. When it is hidden, macOS relocates the control beside the standard window controls.

On current macOS this uses the native Liquid Glass appearance.

### Detail navigation

The right pane keeps browser-style Back and Forward history.

Two small circular Liquid Glass buttons appear at the upper-right of the right pane:

- Back
- Forward

Trackpad navigation gestures use the same history.

The history follows the actual content displayed in the right pane. Tasks, Notes, Activities, Themes, People, Organizations, Groups, Calendar Events, New Work Entry and New Calendar Event views can therefore participate in the same Back/Forward chain. Explicitly selecting another object always replaces a transient creation view.

Displayed references inside detail views are navigable where appropriate, allowing direct movement between Work items, Themes, People, Groups, Organizations and Calendar Events.

---

## New Entry

`New Entry` is the global Work creation action.

Selecting it opens the **New Work Entry** editor in the right pane regardless of which sidebar area was selected previously.

The keyboard shortcut is:

```text
Command-N
```

The creation form can create:

- Task
- Note
- Activity

It also exposes the relevant Theme, Parent Task, dates, time zones and Work relationships.

The same Work editor is also used when editing an existing Task, Note or Activity. Existing Work opens with its current values pre-filled, while the normal detail page remains read-only.

New Entry is repeatable: after cancelling a creation form, selecting New Entry again opens a fresh form.

---

## Tasks

Tasks represent actionable work.

Task states are:

- To Do
- In Progress
- Completed
- Closed

Tasks can contain further Tasks to arbitrary depth.

They can also participate in Theme membership, relationships, deadlines, chronology and history.

The normal Task detail page is read-only and provides one **Edit** action. Editing opens the same complete Work editor used by New Entry, pre-filled with the Task's content, Themes, Parent, status, lifecycle dates and relationships.

`Created` remains an audit timestamp describing when the Task entered Testudo. `Started` describes when the work actually began and is editable independently, including historical dates earlier than `Created`.

When a Task changes from **To Do** to **In Progress** without an existing `Started` value, Testudo records the transition time automatically. A manually supplied `Started` value is preserved.

---

## Notes

Notes preserve contextual or durable information without requiring Task status.

Notes can live inside the Work hierarchy and can use reminders and relationships where appropriate.

The normal Note detail page is read-only. A single **Edit** action opens the shared Work editor with the Note's current values, including reminder and relationships, already populated.

---

## Activities

Activities record something that happened.

Examples include:

- a discussion
- a decision
- a measurement
- an intervention
- a review
- a completed action
- a resolved problem

Activities are chronological work-log objects.

The normal Activity detail page is read-only. A single **Edit** action opens the shared Work editor with the Activity's existing values, including its occurrence time and relationships.

They are deliberately different from Calendar Events:

```text
Activity       = something recorded as having happened
Calendar Event = a scheduled calendar object
```

---

## Themes

Themes provide semantic classification independently of both the Work hierarchy and the organizational hierarchy.

Themes can themselves be hierarchical.

The current Theme interface exposes:

- name
- parent Theme
- summary
- notes
- related People, Groups and Organizations
- start date
- target date
- tags
- URL
- SF Symbol
- created and updated timestamps

Older Environment files may contain additional legacy metadata fields. Structure code, status, priority and owner remain persistence-compatible but are not exposed by the current Theme interface.

The normal Theme detail view is read-only. A single **Edit** action in the Theme header opens the complete Theme editor, replacing the previous per-property edit controls.

### Multi-Theme Work

A Work item may belong to more than one Theme.

This allows one Task, Note or Activity to participate in several semantic domains without duplication.

### Descendant aggregation

A parent Theme's Related Work includes Work associated with descendant Themes recursively.

For example:

```text
Theme A
└── Theme B
    └── Theme C
```

Work belonging to Theme C can appear in the Related Work views of Theme C, Theme B and Theme A.

This does not silently reassign the Work item to all ancestor Themes.

---

## People

People are first-class professional entities.

A Person can have:

- profile information
- multiple affiliations
- a primary affiliation
- Work relationships
- Related Work

A Person inside a Work Environment is distinct from the installation's Local User Profile.

---

## Organizations

Organizations represent institutional structures such as universities, institutes, departments, companies, observatories and research centres.

Organizations may contain other Organizations.

The current Organization interface exposes:

- full name
- short name
- structural memberships
- affiliated People
- start and target dates
- website
- e-mail
- telephone
- address
- city
- postal code
- country
- tags
- SF Symbol
- notes
- created and updated timestamps

Legacy persisted structure code, status, priority and owner fields remain compatible with older data but are not exposed in the current Organization interface.

Organizations and Groups use the same whole-object editing model as People: the normal detail inspector remains read-only and one **Edit** action opens a complete editor for the object, including structural memberships and affiliated People.

---

## Groups

Groups represent laboratories, teams, committees, collaborations, working groups and similar collective structures.

Groups use the same general structural detail system as Organizations.

Themes, Organizations, Groups and People share a consistent card-based detail presentation.

---

## Work relationships

Work can be linked semantically to People, Groups and Organizations.

Available roles are:

- For
- Requested by
- With
- Assigned to
- Related to

A relationship may be marked **Inherited by children**.

This allows descendant Work items to inherit useful context from a parent Task while still adding their own relationships.

---

## Related Work

People, Themes, Organizations and Groups share a common **Related Work** presentation.

When Related Work exists, the right pane is divided into two independently scrollable regions:

- upper region — Related Work
- lower region — the object's normal detail inspector

When no Related Work exists, the detail inspector uses the full height.

Related Work can contain:

- Tasks
- Notes
- Activities

For Themes, descendant Theme Work can be aggregated recursively.

For Organizations and Groups, relevant Work can be aggregated from descendant structural entities.

Duplicate Work items are suppressed when several descendant paths resolve to the same item.

---

## Calendar

Calendar Events are separate from Activities.

Testudo supports:

- Testudo Calendar Events
- Apple Calendar / EventKit integration
- iCal subscriptions
- links between Calendar Events and Testudo Work
- Environment-level calendar administration where appropriate

External calendar information may be read-only depending on its source.

---

## Time zones

Date and time handling is time-zone-aware.

The device time zone is the default display context, while timestamps can retain their source IANA time-zone identifiers.

This allows Testudo to preserve the absolute instant while presenting dates and times correctly when the user's system time zone changes.

The date/time picker uses a Monday-first calendar layout.

---

## Identity and authentication

Testudo has two distinct identity layers.

### Local Testudo user

The installation-level user has a local Testudo profile and application authentication.

The application supports:

- password changes
- password recovery through security questions
- portable `.testudouser` profile export/import
- Log Out
- complete local Sign Out

### Work Environment users

Each Work Environment has its own membership and authentication.

Environment Administrators can manage Environment membership and supported password administration independently of the local application password.

---

## Demo Environment

The Work Environments screen can generate a complete fictional Demo Environment.

The Demo contains interconnected examples of:

- People
- Organizations
- Groups
- Themes
- Tasks
- sub-tasks
- Notes
- Activities
- Calendar Events
- affiliations
- Work relationships
- chronology and history

Demo dates are generated relative to the date on which the Environment is created.

---

## Portable profiles

The local Testudo profile can be exported as a `.testudouser` file.

This can restore profile information after local Sign Out.

A `.testudouser` file intentionally does not contain Environment passwords, recovery credentials or Environment registrations.

---

## Building from source

Build the application bundle directly with:

```bash
./Scripts/build-app.sh
```

The result is created at:

```text
dist/Testudo.app
```

Testudo uses SwiftPM's current **default build backend**.

The production source is currently maintained as a **zero-warning build** with the supported Xcode 27 / Apple Swift 6.4 toolchain.

Version and build identity are defined centrally in:

```text
Scripts/version.sh
```

### Build a local installer DMG

```bash
./Scripts/build-release.sh
```

or use:

```bash
./Scripts/build-local-dmg.sh
```

---

## Documentation

The complete English user manual is maintained in this repository:

- [Testudo User Manual — PDF](Testudo_manual.pdf)
- [LaTeX source](Documentation/TestudoManual/Testudo_manual.tex)
- [LaTeX document class](Documentation/TestudoManual/testudomanual.cls)

The current documentation edition is **Testudo User Manual 1.2**, documenting Testudo **0.1.6 (build 7)**.

---

## Development status

Testudo is an early public release.

Its interface and data model will continue to evolve.

Maintain independent backups of important `.testudoenv` packages, especially when moving between early versions.

---

## License

Testudo is released under the **MIT License**.

See [`LICENSE`](LICENSE).

---

## Author

**Foivos Karakostas**
