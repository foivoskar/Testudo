Planned Start is an optional date and time associated with a Task.
It specifies when that Task is intended to become available for work.

This document describes the Planned Start feature introduced in
Testudo 0.3.1 (build 17).

## Functional model

Planned Start is independent from the actual Started timestamp.

A Task can have a Planned Start without having started.

The feature does not automatically change Task status.

Task workflow states remain To Do, In Progress, Completed and
Discontinued. Closing a Task remains an independent archive action.

Planned Start is optional. Existing Tasks without a Planned Start
continue to behave as before.

## Date, time and time zones

Planned Start is an absolute timestamp, not a date-only property.

The stored fields are:

- `plannedStartAt`: optional absolute date and time.
- `plannedStartTimeZoneID`: optional IANA time-zone identifier.

The time-zone-aware editor uses the application's existing date
and time editing conventions.

Stored instants remain independent of the device's current
display time zone.

## Parent Tasks and Subtasks

A To Do Task becomes available when its effective Planned Start
has been reached.

The effective Planned Start is the latest applicable timestamp
among the Task itself and its ancestor Tasks.

For example, when a Parent is planned for 10:00 and its Subtask
for 09:00 on the same day, the Subtask becomes available at 10:00.

If the Subtask is planned for 11:00, it becomes available at 11:00.

Tasks already In Progress or with an actual Started timestamp
remain available regardless of future Planned Start values.

This availability calculation does not modify the Task hierarchy
or any stored workflow status.

## Today and Day workspace

Today distinguishes actionable work from upcoming work.

A To Do Task with a future effective Planned Start is not treated
as available for immediate execution.

Upcoming planned starts remain discoverable.

The Day workspace uses the actual current time for Today.
For a future day, it determines which work will have become
available by the end of that day.

The Day workspace continues to distinguish:

- Schedule;
- Planned Starts;
- Planned Work;
- Due & Reminders;
- Day History;
- App Log.

A Planned Start is not an actual historical start event.

## Calendar

Planned Starts appear in the Calendar as occurrences associated
with their existing Tasks.

The calendar provides:

- a monthly indicator;
- a Planned Starts agenda section;
- corresponding entries in the Day workspace.

Selecting an occurrence navigates to the Task.

Planned Start does not create a separate Calendar Event or Activity.

## History

Creating, changing or removing Planned Start produces a distinct
History event of type `plannedStartChanged`.

This event is separate from the existing deadline-related
`schedule` functionality and from an actual Task start.

Historical Planned Start changes remain recorded when the current
Planned Start is removed.

## Database format and compatibility

The public Testudo 0.3.0 release supports compatible schema 8
Work Environments.

Testudo 0.3.1 supports schemas 8 and 9.

An existing schema 8 Environment stays at schema 8 until
Planned Start information is saved.

When Planned Start data or Planned Start History is present,
Testudo 0.3.1 saves the Environment using schema 9.

Once upgraded, the Environment remains at schema 9 even if
the current Planned Start is later cleared.

Testudo 0.3.0 does not understand schema 9 and must not
be used to open an upgraded Environment.

There is no automatic downgrade from schema 9 to schema 8.

The schema 7 migration remains a separate, explicit process.

## Multiple Macs and synchronized storage

Before adding Planned Start to an Environment synchronized
between multiple Macs, every Mac that needs that Environment
must run a version supporting database schema 9.

Otherwise, older Testudo installations will reject the
upgraded Environment.

Do not edit the same Work Environment simultaneously
from different Macs.

Filesystem synchronization through Dropbox, iCloud Drive
or similar providers does not provide automatic conflict
resolution or simultaneous multi-device editing.

Keep an independent backup of an Environment before its
first schema 9 upgrade.

## Persistence safeguards

Task editing reports a failure when the database cannot
be saved and restores the previous in-memory Task data.

Copying an active Work Environment is cancelled if its
pending data cannot be saved first.

The compatibility gate permits schema 9 snapshots in the
development version and rejects unsupported future schemas.

## Verification

The initial feature implementation was committed as:

`80f0122 — Add timezone-aware Planned Start with schema 9 safeguards`

The development branch passed 110 automated tests:

- 35 Testudo integration tests;
- 75 TestudoCore tests.

Tests include:

- decoding Tasks without Planned Start;
- date and IANA time-zone round trips;
- History creation and removal;
- Planned Start and Deadline validation;
- Parent/Subtask availability;
- exact planned availability times;
- schema 8 preservation for ordinary Tasks;
- schema 8 to schema 9 upgrade;
- schema 9 Environment reopening;
- rejection of unsupported schema 10;
- failed-save rollback;
- failure-safe Environment copying.

The successful automated tests do not replace a final
manual UI acceptance test before release.

## Release status

Planned Start was introduced in Testudo 0.3.1 (build 17).

The release is distributed through the source-first local
installation workflow. No prebuilt executable is published.
