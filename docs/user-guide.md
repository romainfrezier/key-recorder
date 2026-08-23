# Key Recorder — User Guide for Researchers

Key Recorder is designed for short, controlled experiments where a researcher
needs to record when one of two events occurs. The event is represented by a
keyboard key pressed by the researcher during the observation.

It does not identify a person, interpret what is typed, or send data anywhere.
It measures the time for which the two selected keys are held and saves the
result as a CSV file on the Mac. Key Recorder also keeps a local archive and a
searchable catalogue so that the result can be reviewed and exported again
later.

## A typical biology protocol

For an animal-behaviour study, you might define:

- **Key 1 — Food dispenser**: press `A` while the animal interacts with the
  dispenser.
- **Key 2 — Lever**: press `B` while the animal interacts with the lever.
- **Duration**: the length of the observation, for example 10 minutes.
- **Interval**: the size of each analysis period, for example 30 seconds.

Before starting, write down the key definitions, duration, interval, operator,
experiment identifier, and observation conditions in your lab notebook. You
can also enter this information in the session details after the observation;
Key Recorder keeps it in its local catalogue next to the archived CSV.

## First setup

1. Open Key Recorder.
2. Open **Key Recorder → Preferences…** with `⌘,`.
3. In **General**, choose English, French, or Italian if needed.
4. In **Recording**, choose the two keys and give them meaningful names such
   as `Food dispenser` and `Lever`.
5. Use **Detect…** if you are unsure which physical key macOS receives. This
   is recommended for non-US keyboards.
6. Set the duration and interval in seconds.
7. In **General**, choose Automatic, Light, or Dark appearance if needed.
8. Choose the CSV destination in the main window. This creates an external copy;
   Key Recorder also keeps its own internal archive.

The application remembers these choices for the next session. Use
**Reset Recording Settings** in Preferences to return to the defaults.

## Sessions and the local archive

The **Sessions** sidebar lists observations already known to Key Recorder. Use
the search field to find a session by title, experiment ID, subject, operator,
protocol, tag, or note.

Select a session to:

- view the CSV directly in the application;
- edit its title, experiment ID, subject, operator, protocol, tags, and notes;
- verify that the archived CSV is unchanged;
- export another copy to any folder;
- reveal the archived CSV in Finder.

The application archive lives in:

```text
~/Library/Application Support/Key Recorder/
├── Sessions.sqlite3
└── CSV/
```

The CSV in this archive is the protected measurement copy. Files exported to
Downloads, the Desktop, or a shared laboratory folder are copies and can be
recreated as often as needed. Importing an old CSV also creates an internal
copy, so the original file can be moved without breaking the session history.

Removing a session from the list does not delete its archived CSV. Permanent
archive cleanup is a separate operation.

## Permissions

macOS protects global keyboard monitoring. Key Recorder uses a passive event tap
and needs **Input Monitoring** to receive the two selected keys while a
measurement is being prepared or recorded.

When macOS opens System Settings, enable Key Recorder under
**Privacy & Security → Input Monitoring**. If the permission message remains
visible, quit and reopen the application after changing the setting.

Key Recorder does not post, modify, or automate keyboard input, so
**Accessibility is not required for passive recording** in the current release.
The application does not use these permissions to read passwords or save
general keyboard input.

## Running an observation

1. Confirm the key names and experiment settings.
2. Click **Start Recording**, or press `⌘R`.
3. Press and hold the configured key while the event is occurring. Release it
   when the event ends.
4. Follow the live duration values in the Status section.
5. Wait for the countdown to finish, or press `⌘.` / **Stop Recording** to end
   early.

An early stop still exports the data already collected. Its filename contains
`-partial`, so it cannot be confused with a complete observation.

## Understanding the CSV

Example:

```csv
interval,Food dispenser,Lever
0s - 30s,12.450,4.200
30s - 60s,8.100,10.000

TOTAL,20.550,14.200
```

- Each row is one analysis interval.
- Values are durations in seconds, not numbers of interactions.
- `TOTAL` is the sum of each key's durations across the observation.
- A participant can interact with another activity while neither key is
  pressed; that time appears as zero for both configured events.
- The CSV is suitable for spreadsheet software, R, Python, and other analysis
  tools.

The interval is an analysis choice, not a sampling delay. For example, a
30-second interval produces one row for each 30-second period. Choose an
interval that matches the temporal precision needed by the protocol.

## Reproducible lab practice

For every session, keep the following in the session details and project
records:

- experiment and subject identifiers;
- date, start time, operator, and observation conditions;
- the meaning of Key 1 and Key 2;
- duration and interval;
- whether the file is complete or `-partial`;
- any interruption, permission change, or operator note.

Do not put confidential subject information in the key names or filename unless
your local data-management policy allows it. Key Recorder has no network
service and does not upload the CSV, but the local catalogue and archive still
need to follow your institution's Mac storage and backup policy.

## Troubleshooting

### No data appears

Check that the correct physical keys were detected, both permissions are
enabled, and the configured key is pressed and released during the session.

### The permission status does not update

Enable the permission in **System Settings → Privacy & Security**, then quit
and reopen Key Recorder. macOS can require a relaunch after a permission change.

### The CSV is marked partial

This means the session was stopped before its configured duration. The file is
valid and contains the completed portion of the observation. Keep it only if
your protocol permits interrupted observations.

### The DMG shows a security warning

The public build is ad hoc signed and is not notarized with Apple. Verify that
the DMG came from the expected release, then follow the macOS prompt to open it
or build the application from source.
