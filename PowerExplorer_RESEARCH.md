# Power Explorer 1.2 — Windows-native metadata research

Date: October 23, 2026. This is an API design note, **not** a report on the user's actual installed power configuration.

## Source precedence

1. Windows native `PowrProf.dll` metadata, retrieved live on the target machine.
2. Locally registered `HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings` definitions if the corresponding API call does not return data.
3. GUID-matched source-linked explanatory notes in the bundled offline JSON catalog. These annotations never replace local names, option values, or numeric bounds.

Settings are enumerated through `PowerEnumerate` access flags `ACCESS_SCHEME=16`, `ACCESS_SUBGROUP=17`, `ACCESS_INDIVIDUAL_SETTING=18`. The enumerated GUIDs are combined with the registry inventory so hidden or unpopulated definitions remain inspectable. See [PowerEnumerate](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerenumerate).

## Native metadata calls

| Windows API | UI information | Microsoft documentation |
|---|---|---|
| `PowerReadFriendlyName` | Scheme, subgroup, setting labels | [Learn](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreadfriendlyname) |
| `PowerReadDescription` | Windows native descriptions | [Learn](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreaddescription) |
| `PowerReadPossibleFriendlyName` | Enum choices, localized | [Learn](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreadpossiblefriendlyname) |
| `PowerReadPossibleDescription` | Optional choice help text | [Learn](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreadpossibledescription) |
| `PowerReadPossibleValue` | Choice value; only 4-byte REG_DWORD supported for editing | [Learn](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreadpossiblevalue) |
| `PowerReadValueMin` / `Max` / `Increment` | Numeric range validation | [Min](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreadvaluemin), [Max](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreadvaluemax), [Increment](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreadvalueincrement) |
| `PowerReadValueUnitsSpecifier` | Units | [Learn](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreadvalueunitsspecifier) |
| `PowerReadSettingAttributes` | Hidden attribute combined from subgroup/setting | [Learn](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreadsettingattributes) |
| `PowerReadACValueIndex` / `PowerReadDCValueIndex` | Configured scheme indices | [AC](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreadacvalueindex), [DC](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreaddcvalueindex) |

Native string APIs return UTF-16 text and report buffer sizes **in bytes**. All native metadata calls use `RootPowerKey=NULL`. Failure to read name/description triggers registry fallback, never a fabricated description.

The Windows output command `powercfg /qh SCHEME_CURRENT` can independently verify most names, current scheme values, and numeric or enumerated options. [Powercfg options](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options).

## Safety and correctness boundaries

- API metadata is evidence of an OS setting definition, not evidence that firmware or hardware responds to the setting.
- API enumeration and registry inventory may differ; the program uses their union, not a count of 13 known GUIDs.
- For enumerated choices, only contiguous possible-setting indices beginning at zero and 4-byte REG_DWORD values are supported for editing; other option formats fall back to read-only information where applicable.
- Registry definitions can be present even where a scheme does not return an AC/DC value. These are labeled “not exposed.”
- Exported catalogs carry a provenance field for each name/description and each choice list.
- Windows Education managed policies are not modified and can supersede displayed plan values.
- This build has not undergone runtime verification on Windows 11 Education.

The existing `PowerExplorer_Knowledge.json` remains a separately sourced research annotation collection, not an OS metadata catalog.
