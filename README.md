# Testudo

<p align="center">
  <img src="Sources/Testudo/Resources/TestudoIcon.png" alt="Testudo application icon" width="180">
</p>

**Testudo** is a native macOS application for organizing complex professional and research work across tasks, notes, activities, calendar events, people, groups, organizations, themes, and independent Work Environments.

It is designed especially for researchers, research software engineers, technical staff, academics, and people whose work involves multiple projects, institutions, collaborators, and scientific domains.

**Current documented version: Testudo 0.1.4 (build 5).**

## Installation

Testudo currently uses a **source-first local installation model**.

The application is compiled directly on the Mac where it will be used. No prebuilt Testudo executable is required, and no paid Apple Developer account is needed for this installation method.

### Quick install

The easiest installation method is:

    curl -fsSL https://raw.githubusercontent.com/foivoskar/Testudo/main/install.sh | bash

This command downloads the Testudo installation script from the public repository.

The script then:

- verifies that the Mac is compatible
- checks the Apple developer tools
- checks that Swift 6.0 or later is available
- clones the Testudo source code into `~/Testudo`
- safely updates an existing clean `~/Testudo` checkout
- builds Testudo locally in release configuration
- ad-hoc signs the locally compiled application
- creates and verifies a local installer DMG
- opens the finished installer

The Testudo application executable itself is **not downloaded prebuilt**. It is compiled locally from the public source code on the user's Mac.

When the installer opens, drag `Testudo.app` into `Applications`.

The automatic installer never overwrites an existing source checkout containing local modifications.

### Manual local build

Users who prefer to inspect and run each step manually can clone Testudo themselves:

    git clone https://github.com/foivoskar/Testudo.git
    cd Testudo

Then build the local installer:

    ./Scripts/build-local-dmg.sh

The resulting installer is written to `dist/`, for example:

    dist/Testudo-0.1.4-macOS-arm64.dmg

When the build finishes, the completed installer opens automatically.

Drag `Testudo.app` into `Applications`.

### Requirements

- macOS 14 or later
- Apple Silicon Mac
- Swift 6.0 or later
- Xcode or Apple Command Line Tools
- Git

If Apple developer tools are not installed, request them with:

    xcode-select --install

After the installation of the developer tools completes, run the Testudo installation command again.

### Updating Testudo

If the quick installer was used previously, simply run the same command again:

    curl -fsSL https://raw.githubusercontent.com/foivoskar/Testudo/main/install.sh | bash

The installer detects the existing `~/Testudo` checkout and performs a safe fast-forward update before rebuilding the application.

Alternatively, update manually:

    cd ~/Testudo
    git pull --ff-only
    ./Scripts/build-local-dmg.sh

If Testudo was cloned somewhere else, run the equivalent commands from that repository.

### Custom source directory

The installer uses:

    ~/Testudo

by default.

A different source directory can be selected by downloading the installer script and supplying `--source-dir`, or by setting the `TESTUDO_SOURCE_DIR` environment variable.

For example:

    curl -fsSL https://raw.githubusercontent.com/foivoskar/Testudo/main/install.sh -o /tmp/testudo-install.sh
    bash /tmp/testudo-install.sh --source-dir "$HOME/Developer/Testudo"

### Inspect before running

Users who prefer to inspect the installer before executing it can download it first:

    curl -fsSL https://raw.githubusercontent.com/foivoskar/Testudo/main/install.sh -o testudo-install.sh

Inspect `testudo-install.sh`, then run:

    bash testudo-install.sh

### Source archive alternative

Git is not required by the Testudo build scripts themselves.

A GitHub source archive can also be downloaded and extracted manually. From the extracted Testudo directory, run:

    ./Scripts/build-local-dmg.sh

Using the Git checkout or quick installer is recommended because subsequent updates are simpler.

### Distribution model

Testudo currently does not use prebuilt application binaries as its normal installation channel.

Git tags identify source versions of Testudo. Installation is performed by compiling Testudo locally from the public source code.

This keeps the current installation model independent of Developer ID distribution and Apple notarization of a prebuilt Testudo executable.

## Documentation

A complete English user manual is available directly from this repository:

- [Testudo User Manual — PDF](Testudo_manual.pdf)
- [LaTeX source](Documentation/TestudoManual/Testudo_manual.tex)
- [LaTeX document class](Documentation/TestudoManual/testudomanual.cls)

The manual covers installation, Work Environments, authentication, navigation, Tasks, Notes, Activities, Calendar Events, Themes, People, Groups, Organizations, external calendars, time zones, data portability, administration, security, troubleshooting, recommended workflows and technical reference material.

The PDF is generated from the LaTeX sources stored under `Documentation/TestudoManual/`.

## Core idea

Testudo combines three things that are often separated in conventional task managers:

- hierarchical work
- people and organizational structure
- chronological activity and history

A Work Environment can contain Tasks, sub-tasks, Notes, Activities, Calendar Events, Themes, People, Groups, Organizations, affiliations, relationships, and historical information.

Work can be related to entities through semantic relationships such as:

- For
- Requested by
- With
- Assigned to
- Related to

## Work Environments

Testudo supports multiple independent **Work Environments**.

Each Environment is stored as a portable `.testudoenv` package.

A typical Environment package contains:

    Example.testudoenv/
    ├── EnvironmentManifest.json
    ├── EnvironmentData.json
    ├── EnvironmentCredentials.json
    └── EnvironmentIcon.png

The icon file is optional.

Environment packages can be stored locally or in a synchronized filesystem location such as Dropbox, iCloud Drive, OneDrive, or another location available to macOS.

Testudo works directly with the selected package rather than copying its data into an internal database.

## Local-first design

Testudo is designed as a local-first macOS application.

There is no required Testudo cloud service. Environment data remains inside its `.testudoenv` package.

Application-level state such as the local Testudo profile, registered Environment locations and local authentication state is stored separately from Environment data.

## Identity and authentication

Testudo has two distinct identity layers.

### Testudo application user

The local application user has a Testudo profile and application password.

The application account supports:

- password changes
- password recovery using three security questions
- portable `.testudouser` profile export/import
- Log Out
- complete local Sign Out

### Work Environment users

Each Work Environment has its own memberships, roles and authentication.

Environment users can:

- sign in with an Environment username and password
- change their own password
- configure three security questions
- recover a forgotten password using one of those questions

Environment Administrators can assign a new password to another Environment member without knowing the previous password.

Application authentication and Environment authentication are independent.

## Work

### Tasks

Tasks represent actionable work and can have the following states:

- To Do
- In Progress
- Completed
- Closed

Tasks can contain:

- sub-tasks
- Notes
- Activities

Nested Tasks can themselves contain further Work, allowing arbitrarily deep Work hierarchies.

Tasks can have deadlines, scheduling information, history, relationships, and Theme membership.

### Notes

Notes preserve contextual or durable information inside the Work hierarchy without requiring Task status.

Notes can also participate in reminders and relationships where appropriate.

### Activities

An **Activity** records something that happened while work was being performed.

Examples include a discussion, decision, intervention, measurement, review, completed action, or resolved dependency.

Activities are chronological work-log objects.

They are deliberately separate from Calendar Events:

    Activity       = something recorded as having happened
    Calendar Event = a scheduled calendar object with a time interval

## Themes

Themes provide a semantic classification layer independent of both the Work hierarchy and the organizational hierarchy.

Themes can be hierarchical.

A Theme may contain metadata such as:

- name
- summary
- notes
- code
- status
- priority
- owner
- start date
- target date
- tags
- URL
- visual symbol

### Multi-Theme Work

A Work item can belong to more than one Theme.

This allows a Task, Note, or Activity to participate in several semantic domains without duplicating the Work item.

The current model supports explicit multi-Theme membership while remaining compatible with older single-Theme records.

### Parent Theme aggregation

The **Related Work** view of a parent Theme includes:

- Work assigned directly to the Theme
- Work belonging to child Themes
- Work belonging to all deeper descendant Themes

Aggregation is recursive.

For example:

    Theme A
    └── Theme B
        └── Theme C

A Note belonging to Theme C appears in the Related Work views of Theme C, Theme B, and Theme A.

This does not reassign the Work item to the parent Themes. It is a consolidated parent view.

## Organizations

Organizations represent institutional structures such as universities, institutes, departments, companies, observatories, and research centres.

Organizations can contain other Organizations and Groups.

They can hold rich metadata including:

- full name
- short name
- code
- status
- priority
- owner
- website
- e-mail
- telephone
- address
- city
- postal code
- country
- tags
- notes

An Organization's **Related Work** pane includes both its own Work context and the Related Work of all descendant entities.

## Groups

Groups represent teams, laboratories, committees, collaborations, working groups, project teams, and technical teams.

Groups may exist inside Organizations or other supported containers and may contain People.

A Group's **Related Work** pane uses the same presentation as People, Themes, and Organizations.

Parent Groups aggregate Related Work from descendant entities recursively.

## People

People are first-class entities with detailed professional profiles and affiliations.

A Person can have multiple affiliations and can belong to multiple Groups and Organizations.

One affiliation may be marked as primary.

People can participate in Work relationships through semantic roles such as:

- For
- Requested by
- With
- Assigned to
- Related to

The Person detail view uses the same **Related Work** presentation as Themes, Groups, and Organizations.

## Related Work

People, Themes, Organizations, and Groups use a common **Related Work** pane at the top of the right-hand detail view.

When Related Work exists, the right pane is divided into two independently scrollable halves:

- upper half: Related Work
- lower half: the object's normal detail inspector

If there is no Related Work, the normal detail view occupies the full height.

Related Work can contain:

- Tasks
- Notes
- Activities

Each compact row can display:

- Work icon
- title
- Work type
- Task status where applicable
- Theme
- deadline where applicable
- description/body preview
- creation date at the far right

The same typography, spacing, and navigation behaviour is used in all four structural areas.

### Descendant aggregation

Related Work propagates upward for presentation.

For Themes, a parent sees Work belonging to all descendant Themes.

For Organizations and Groups, a parent sees Related Work associated with descendant Organizations, Groups, and People.

Aggregation is recursive and does not change the underlying memberships or relationships.

Work items are not duplicated merely because several descendant paths make the same Work item relevant.

### Relationship inheritance

Related Work aggregation is separate from Work relationship inheritance.

A Work relationship can also be marked **Inherited by children**, allowing descendant Work items to inherit a semantic relationship defined on a parent Work item.

Both mechanisms can operate at the same time.

## Navigation

Testudo uses a native three-column macOS interface:

1. main navigation
2. lists, trees, and collections
3. detail pane

### Middle-column selection

The selected item in the middle column uses an application-controlled full-row blue selection.

The selection fills the available row width and height and uses subtle rounded corners.

The same treatment is applied to ordinary rows and hierarchical DisclosureGroup rows, including Themes and nested Work.

### Global object navigation

Displayed references throughout the detail interface are navigable wherever navigation is semantically appropriate.

Supported destinations include:

- Tasks
- Notes
- Activities
- Themes
- People
- Groups
- Organizations
- Calendar Events

Descriptions and previews that represent a particular object also navigate to their owning object.

For example:

- a Related Work title opens that Work item
- its body preview opens the same Work item
- a displayed Theme name opens the Theme
- Calendar Event Work and Theme references open their corresponding objects

Editors, selectors, menus, disclosure controls, and other interactive controls retain their original editing or selection behaviour.

The detail pane maintains Back and Forward navigation history.

## Demo Environment

The Work Environments screen includes **Load Demo Environment**.

This generates a complete fictional academic and scientific working environment intended to demonstrate Testudo without requiring the user to enter data manually.

The Demo environment is centred on software development and scientific work in a university or research institute with extensive international collaboration.

It includes areas such as:

- Research Software Engineering
- Scientific Computing and HPC
- Data Infrastructure
- AI and Data Science
- Earth and Environmental Sciences
- Physics and Astronomy
- Computational Biology
- Chemistry and Materials Science
- Instrumentation and Sensors
- Open Science and FAIR Data
- International Collaborations
- Seminars and Training
- Research Administration

The generated Demo contains interconnected:

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
- work relationships
- history

Demo dates are generated relative to the day on which the Environment is created.

The generated timeline covers approximately:

- one month before the creation date
- two months after the creation date

Operational dates are placed on working days and during normal working hours.

The current Testudo application user becomes the Administrator of the Demo Environment and their compatible profile information is used for the corresponding Person.

Demo Environments initially contain no Environment passwords, allowing immediate exploration.

Repeated Demo creation uses the lowest available name:

    Demo
    Demo-2
    Demo-3

If a numbered Demo is removed from Testudo, its available number can be reused later.

## Environment icons

Each Work Environment can optionally use a custom icon.

The icon is stored directly inside the `.testudoenv` package.

If no custom icon exists, Testudo uses its default Environment icon.

Environment Administrators can change or restore the icon through Admin Tools.

## Portable Testudo profiles

The local Testudo user profile can be exported as a `.testudouser` file.

This provides a convenient way to restore profile information after a complete local Sign Out.

Environment registrations, Environment passwords and recovery credentials are intentionally not stored in `.testudouser`.

## Building from source

Developer requirements:

- macOS 14 or later
- Apple Silicon
- Swift 6.0 or later
- Xcode or Apple Command Line Tools

Build the application bundle directly with:

    ./Scripts/build-app.sh

The resulting application is created at:

    dist/Testudo.app

The default Testudo version and build number are defined in:

    Scripts/version.sh

This file is the single source of truth used by the build scripts.

## Building a local installer DMG

For development, testing, or release preparation, build the local installer DMG with:

    ./Scripts/build-release.sh

The default version and build number are read from `Scripts/version.sh`.

A specific version and build number can still be supplied explicitly:

    ./Scripts/build-release.sh 0.2.0 6

The resulting disk image is written to `dist/`, for example:

    dist/Testudo-0.1.4-macOS-arm64.dmg

The DMG contains:

- `Testudo.app`
- an `Applications` shortcut

The build script sizes the writable installer image from the current application bundle instead of relying on a fixed application-size assumption.

Installation consists of dragging Testudo into the Applications folder.

## Release status

Testudo is currently an early public release.

The application and its data model may continue to evolve.

Maintain backups of important `.testudoenv` packages, particularly while using early releases.

## License

Testudo is released under the **MIT License**.

See the `LICENSE` file.

## Author

**Foivos Karakostas**
