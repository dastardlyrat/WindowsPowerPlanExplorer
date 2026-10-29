# Windows Power Plan Explorer

Power Explorer is a Windows PowerShell and Windows Forms application for
inspecting power plans, their setting definitions and AC/DC values, and device
power diagnostics. It uses native Windows metadata so a setting can be read
with its name, description, possible choices, and evidence source together.

The application opens with editing disabled. Collection is an explicit action.
Optional plan edits require a supported value, confirmation, and a new power-plan
backup. Device inspection remains read-only.

This tree contains the Power Explorer 1.2 code with the subsequent sectional UI
and manual-collection work described in the
[detailed manual](PowerExplorer_README.txt).

## Start

Use **Windows PowerShell 5.1** in **STA** mode. The application uses Windows
Forms and built-in Windows tools; PowerShell 7 is not the supported launcher.

Keep all repository files together, especially `PowerExplorer.ps1` and
`PowerExplorer_UI.ps1`. From the repository directory:

```powershell
powershell.exe -NoLogo -NoProfile -STA -File .\PowerExplorer.ps1
```

[Launch-PowerExplorer.cmd](Launch-PowerExplorer.cmd) is also included. Run the
application from a folder you are authorized to use and under the machine's
applicable execution policy.

The project targets Windows power-management inspection, with Windows 11
Education represented in the original package. Compatibility with a particular
edition, policy configuration, driver set, or display scaling still needs live
validation on that system.

## Inspect before changing

1. Open **Power plans** and choose **Collect / refresh plans**.
2. Select a plan and browse its setting groups. Search and result selection use
   the collected snapshot.
3. Read the separate description and evidence/reference sections. Inspect the
   available choices or numeric range alongside AC and DC values.
4. Use **Export catalog** when you need the discovered settings, values, and
   provenance as a local JSON snapshot.
5. Open **Devices and wake**, choose **Collect / refresh devices**, and inspect
   the PnP and power diagnostics.
6. Use **Read device properties** when additional properties are needed for the
   selected device.

Opening the window or changing tabs does not start a live inventory. Selecting
an available plan explicitly reads that plan. Device selection displays the
collected data and cached property results.

The two tabs keep navigation, results, details, actions, and collection status
in separate sections. Detail text is read-only, selectable, and copyable.

## Optional plan edits

The edit checkbox, input controls, and persistent mode indicator make the edit
state visible. Editing remains constrained by registered choices/ranges,
available AC/DC indices, and the collected policy indicators.

A confirmed edit creates a new `.pow` backup before using native `powercfg`
commands to apply the selected value. Backups are not silently reused after
earlier changes. Collection turns editing off; a failed plan refresh keeps it
unavailable until a successful refresh.

Policy indicators are snapshot observations. Unknown or unreadable checks lock
editing, but the application does not continuously monitor organization policy.
Elevation may be required for a particular operation; the application does not
request it or bypass policy restrictions.

## Where the information comes from

| Source | Role |
|---|---|
| `PowrProf.dll` | Primary enumeration and friendly-name/description metadata for schemes, groups, settings, and possible values. |
| Registered power-setting definitions | Fallback definitions and resource strings when native metadata is unavailable. |
| `powercfg`, PnP, and Windows diagnostic sources | Plan values and device/wake observations. |
| [PowerExplorer_Knowledge.json](PowerExplorer_Knowledge.json) | Explanatory reference material and links, rather than live machine facts. |

The UI labels metadata provenance. A registered setting or displayed value
does not by itself establish hardware support, an observable effect, or an
effective organization policy.

## Snapshots and collection behavior

One read operation runs at a time. Replacement data is staged, and a failed
refresh retains the previous completed snapshot. Retained catalogs can still
be exported.

Collection is synchronous in this build. A slow provider can block interaction
until it returns; there is no background worker, cancellation, or provider
timeout. Conflicting controls and window closing are disabled during reads.

JSON exports can contain the computer name and installed configuration. Review
them before sharing and keep machine-specific inventories out of repository
issues and commits.

## Source map

| File | Responsibility |
|---|---|
| [PowerExplorer.ps1](PowerExplorer.ps1) | Native API integration, collection, state coordination, validation, backups, and plan application. |
| [PowerExplorer_UI.ps1](PowerExplorer_UI.ps1) | UI composition, section containers, sizing, and locked rich-text helpers. |
| [PowerExplorer_Knowledge.json](PowerExplorer_Knowledge.json) | Bundled explanatory references. |
| [PowerExplorer_README.txt](PowerExplorer_README.txt) | Detailed operating notes and recorded development checks. |
| [PowerExplorer_RESEARCH.md](PowerExplorer_RESEARCH.md) | Existing research and source references. |
| [PowerExplorer_SHA256SUMS.txt](PowerExplorer_SHA256SUMS.txt) | SHA-256 values for the current packaged source files and documentation. |

## Validation and contribution

The existing development notes record sample-data checks of both tabs, normal
and minimum layouts, text selection, editing-state transitions, manual startup,
overlap prevention, and failed-refresh retention. The clean-build review also
parsed both PowerShell files with Windows PowerShell 5.1 and verified source
hashes.

Those checks did not establish live inventory accuracy, policy handling,
backup/apply correctness, Windows 11 Education compatibility, other DPI
settings, or multi-monitor behavior.

For UI work, begin in `PowerExplorer_UI.ps1` and validate geometry at both normal
and minimum sizes. For collection or editing changes, trace the corresponding
logic in `PowerExplorer.ps1` and keep the evidence, backup, and confirmation
contracts explicit. Use sample providers for layout-only checks.

Report the operation, relevant setting or device category, and the first error
when describing a failure. Remove private paths and machine-specific inventory
content from any shared diagnostic material.

No standalone project license is included in this tree. Existing notices and
reference material are preserved.
