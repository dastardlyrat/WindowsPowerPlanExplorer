POWER EXPLORER 1.2 — Windows 11 Education
=========================================

WHAT'S NEW
----------
Sectional UI and manual collection increment (2026-10-28):
* PowerExplorer_UI.ps1 owns UI composition, named section containers, toolbar
  flow sizing, and locked rich-text section helpers. Keep it beside the main
  script. Both tabs have independent navigation, results and text sections.
* Description and Evidence and reference are separate locked rich-text views.
  Device details wrap; System diagnostics preserves line structure with its
  own scrolling. Text remains enabled, selectable and copyable; automatic URL
  activation is disabled. Reference buttons remain explicit actions.
* Opening the window or Devices tab does not collect live inventory. Use
  Collect / refresh plans or Collect / refresh devices. Selecting an available
  plan explicitly reads that plan; search and result selection use snapshots.
* Power policy indicators are read with the plan snapshot, not when filtering
  or selecting a setting. Unknown/unreadable checks lock editing. These are
  snapshot indicators, not continuous monitoring of organization policy.
* Extra driver properties require Read device properties. Device selection
  itself displays collected data and cached property results.
* One read operation runs at a time. The collection section shows stages,
  completion times and failures independently of browsing status. Replacement
  data is staged; a failed refresh retains the previous completed snapshot.
  Editing is turned off for collection and remains unavailable after a failed
  plan refresh until a successful plan refresh. Retained catalogs can still
  be exported; source values and existing export schema are unchanged.
* Collection remains synchronous in this increment. Long provider calls may
  block interaction until they return. No background worker, cancellation or
  provider timeout is implemented. Conflicting controls and window closing
  are disabled during reads; no elevation or automatic remediation is added.
* Local Windows PowerShell 5.1 sample checks covered both tabs at 1230x790 and
  990x680, locked text selection, numeric edit-state transitions, manual
  startup, explicit property reads, overlap prevention and failed-refresh
  retention. All live providers were replaced with sample functions. Native
  rich-text print rendering and control geometry were inspected; desktop
  screenshot capture did not expose the isolated sample window. Other DPI,
  multi-monitor behavior and real collection/application remain unverified.
* Static contract comparison confirmed 29 existing function bodies, including
  value validation, native setting collection, backup and catalog export, plus
  the Apply click handler, remain text-identical to the prior UI commit.

Local UI increment (2026-10-28, codex/ui-first-layout):
* Browsing controls occupy their own resizing row. Actions and the editing
  checkbox are on a separate wrapping row, without horizontal scrolling.
* Setting details resize with the window and splitters. Plugged in (AC) and
  Battery (DC) inputs share the available width; Apply and reference buttons
  occupy their own row.
* A separate persistent status indicator shows whether editing is enabled.
  Enabling the checkbox still requires the existing per-setting validation;
  the indicator does not claim that every selected setting is editable.
* Collection, policy detection, validation, confirmation, backup and powercfg
  apply logic are unchanged by this UI increment.

Windows Power Management APIs (PowrProf.dll) now supply the primary descriptive
metadata. Previous versions relied on registry FriendlyName/Description resources.

* Enumerates power schemes, subgroups and settings through PowerEnumerate;
  combines these lists with registry definitions to avoid dropping registered
  but currently unused settings.
* Uses PowerReadFriendlyName and PowerReadDescription for scheme, subgroup,
  and setting names/descriptions whenever Windows provides them.
* Uses PowerReadPossibleFriendlyName/Description/Value for enumerated choices;
  PowerReadValueMin/Max/Increment/UnitsSpecifier for numeric options.
* Falls back to local registry resource strings when the API returns no data.
* Shows each setting's name/description provenance and possible choices.
* Adds Export catalog: a read-only JSON snapshot of discovered settings,
  names, descriptions, GUIDs, ranges, visibility, and current AC/DC indices.
* Preserves the left-list layout correction introduced in version 1.1.
* Exports a new .pow backup for EACH confirmed edit; does not reuse a stale
  backup after a prior edit.
* Changing schemes refreshes discovered settings as well as their values.

RUN
---
1. Extract ALL ZIP files into one folder.
2. Double-click Launch-PowerExplorer.cmd, OR in PowerShell 5.1 run:
   powershell.exe -NoLogo -NoProfile -STA -File .\PowerExplorer.ps1
3. Power plans tab: click Collect / refresh plans, choose a plan, browse groups
   at left, inspect settings at
   right. Search description/name/category. Hidden entries appear by default.
4. To export the complete inventory for review, click Export catalog and save
   the generated JSON file. The application does not contact the internet.
5. Devices and wake tab: click Collect / refresh devices, then inspect read-only
   PnP and power diagnostics. Read device properties requests additional data
   for the selected device.

VERIFY AGAINST WINDOWS
----------------------
In a separate PowerShell window:
   powercfg /qh SCHEME_CURRENT > "$env:USERPROFILE\Desktop\PowerSettings.txt"

The default powercfg output includes native readable setting/subgroup names
and choices. PowerReadDescription can provide additional descriptions.

SOURCES AND TRUST
-----------------
1. PowrProf.dll live Windows API  : PRIMARY source for metadata.
2. HKLM...\Control\Power\PowerSettings : FALLBACK for registered definitions.
3. JSON bundled reference data   : explanatory links, NOT machine facts.
4. Device hardware support       : NOT inferred from the presence of settings.

The status line displays how many discovered names came from PowrProf.dll
and how many used registry fallback; details display per-entry provenance.

PRIVILEGE & SAFETY
------------------
- The app opens READ-ONLY. Editing requires an explicit checkbox, a
  registered numerical range/choice, a confirmation, and a .pow backup.
- No hidden/visibility bits, ACPI overrides, device-driver properties,
  organization policies, or sleep-model settings are automatically changed.
- Plan edits use native powercfg commands. Running elevated may be necessary.
- Windows 11 Education domain/MDM policy may override plan values.
- Unsupported OEM, firmware, or hardware features are not unlocked.
- Raw JSON export includes your computer name and installed configuration;
  inspect it before sharing it publicly.

KNOWN LIMITS
------------
- The original package reported static Linux checks only. This UI increment
  passed syntax checks in local Windows PowerShell 5.1.22621.7649 and isolated
  sample-data layout checks at 1230x790 and 990x680, at the session's current
  display scaling. Numeric and choice editors, disabled-by-default editing,
  checkbox transitions and the separate mode indicator were checked.
- Sample-data rendering was visually reviewed. The validation loaded only UI
  helpers and layout, stubbed the selected-setting policy lookup, and omitted
  live collectors, native API startup and setting-changing click handlers.
  It did not establish real policy handling, inventory accuracy, backup/apply
  correctness, Windows 11 Education compatibility or other DPI settings.
- 100% matching to Control Panel depends on Windows API/driver metadata.
- Some settings expose neither a read-only value nor numeric validation; the
  GUI disables those edits. On systems without a DC index, AC-only editing
  is not enabled by this version.
- A power plan setting being registered does not prove its hardware effect.
- Other display scaling, multi-monitor behavior and live runtime performance
  still need local testing.
- Optional device drivers may expose power controls outside power plans;
  these require distinct adapters and are not silently included in plan edits.

PowerExplorer_SHA256SUMS.txt is preserved from the original imported archive.
Its checksums describe that archive version, not this modified UI branch.

Restoring an exported plan creates an imported power scheme:
    powercfg /import "C:\path\backup.pow"
Inspect the new scheme before activating it.
