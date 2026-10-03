# Testudo

<p align="center">
  <img src="Sources/Testudo/Resources/TestudoIcon.png" alt="Testudo application icon" width="180">
</p>

**Testudo** is a native macOS application for organizing complex professional and research work across tasks, notes, activities, calendar events, people, groups, organizations, themes, and independent Work Environments.

It is designed especially for researchers, research software engineers, technical staff, academics, and people whose work involves multiple projects, institutions, collaborators, and scientific domains.

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

Tasks can have the following states:

- To Do
- In Progress
- Completed
- Closed

Tasks may contain:

- sub-tasks
- Activities
- Notes

Tasks can have deadlines and can be related to People, Groups, Organizations and Themes.

Task status uses a consistent visual language throughout Testudo:

- To Do — red
- In Progress — orange
- Completed — green

### Activities

An **Activity** records something that happened while working on a Task.

Activities may optionally have a date and time.

Activities are chronological work-log objects and are distinct from Calendar Events.

### Notes

Notes can exist within the work hierarchy and can include reminders.

### Calendar Events

Calendar Events represent scheduled events and are managed separately through Testudo's Calendar.

The word **Event** is reserved for Calendar Events; work-log entries inside Tasks are called **Activities**.

## Themes

Themes provide a semantic classification layer independent of organizational structure.

Themes can be hierarchical and can be related to work, People, Groups and Organizations.

## Organizations

Organizations can contain other Organizations and Groups.

They can also be related directly to work.

## Groups

Groups can exist inside or outside Organizations.

A Group can contain People and participate in work relationships.

## People

People have detailed profiles and can have multiple affiliations.

A Person can belong to multiple Groups and Organizations and can be related to work through semantic roles.

## Navigation

Testudo uses a three-column native macOS interface:

1. main navigation
2. lists and collections
3. detail pane

References inside detail panes are navigable.

For example, a related Task, Theme, Person, Group or Organization can be opened directly from another object's page.

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
