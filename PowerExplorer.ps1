# Power Explorer v1.2 - Windows-native power metadata and device inventory
# Run from Windows PowerShell 5.1 (powershell.exe -STA -File .\PowerExplorer.ps1).
# Read-only by default. Modifying plan values requires checking Enable editing
# and a verified .pow backup. Device power properties remain read-only.

if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Run this script with Windows PowerShell 5.1 (powershell.exe), not PowerShell 7.'
}
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    throw 'Windows Forms requires STA. Start with: powershell.exe -STA -File .\PowerExplorer.ps1'
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public sealed class PowerExplorerChoice {
    public long Value { get; set; }
    public uint Index { get; set; }
    public string Name { get; set; }
    public string Description { get; set; }
}

public static class PowerExplorerNative {
    // Microsoft PowrProf.dll declarations: NULL RootPowerKey; optional GUID pointers;
    // returned string buffer sizes are BYTES and contain UTF-16LE text.
    [DllImport("PowrProf.dll", ExactSpelling=true)]
    private static extern uint PowerReadACValueIndex(IntPtr root, ref Guid scheme, ref Guid subgroup, ref Guid setting, out uint value);
    [DllImport("PowrProf.dll", ExactSpelling=true)]
    private static extern uint PowerReadDCValueIndex(IntPtr root, ref Guid scheme, ref Guid subgroup, ref Guid setting, out uint value);
    [DllImport("PowrProf.dll", ExactSpelling=true)]
    private static extern uint PowerReadSettingAttributes(ref Guid subgroup, ref Guid setting);
    [DllImport("PowrProf.dll", ExactSpelling=true)]
    private static extern uint PowerEnumerate(IntPtr root, IntPtr scheme, IntPtr subgroup, uint access, uint index, byte[] buffer, ref uint size);
    [DllImport("PowrProf.dll", ExactSpelling=true)]
    private static extern uint PowerReadFriendlyName(IntPtr root, IntPtr scheme, IntPtr subgroup, IntPtr setting, byte[] buffer, ref uint size);
    [DllImport("PowrProf.dll", ExactSpelling=true)]
    private static extern uint PowerReadDescription(IntPtr root, IntPtr scheme, IntPtr subgroup, IntPtr setting, byte[] buffer, ref uint size);
    [DllImport("PowrProf.dll", ExactSpelling=true)]
    private static extern uint PowerReadPossibleFriendlyName(IntPtr root, IntPtr subgroup, IntPtr setting, uint index, byte[] buffer, ref uint size);
    [DllImport("PowrProf.dll", ExactSpelling=true)]
    private static extern uint PowerReadPossibleDescription(IntPtr root, IntPtr subgroup, IntPtr setting, uint index, byte[] buffer, ref uint size);
    [DllImport("PowrProf.dll", ExactSpelling=true)]
    private static extern uint PowerReadPossibleValue(IntPtr root, IntPtr subgroup, IntPtr setting, out uint type, uint index, byte[] buffer, ref uint size);
    [DllImport("PowrProf.dll", ExactSpelling=true)]
    private static extern uint PowerReadValueMin(IntPtr root, IntPtr subgroup, IntPtr setting, out uint value);
    [DllImport("PowrProf.dll", ExactSpelling=true)]
    private static extern uint PowerReadValueMax(IntPtr root, IntPtr subgroup, IntPtr setting, out uint value);
    [DllImport("PowrProf.dll", ExactSpelling=true)]
    private static extern uint PowerReadValueIncrement(IntPtr root, IntPtr subgroup, IntPtr setting, out uint value);
    [DllImport("PowrProf.dll", ExactSpelling=true)]
    private static extern uint PowerReadValueUnitsSpecifier(IntPtr root, IntPtr subgroup, IntPtr setting, byte[] buffer, ref uint size);
    [DllImport("shlwapi.dll", CharSet=CharSet.Unicode, ExactSpelling=true)]
    private static extern int SHLoadIndirectString(string source, StringBuilder buffer, uint count, IntPtr reserved);

    private static IntPtr GuidPointer(string value) {
        if (String.IsNullOrWhiteSpace(value)) return IntPtr.Zero;
        Guid guid = new Guid(value);
        IntPtr ptr = Marshal.AllocHGlobal(16);
        Marshal.StructureToPtr(guid, ptr, false);
        return ptr;
    }
    private static void Free(ref IntPtr ptr) {
        if (ptr != IntPtr.Zero) Marshal.FreeHGlobal(ptr);
        ptr = IntPtr.Zero;
    }
    public static string[] Enumerate(string scheme, string subgroup, uint access) {
        if (access != 16U && access != 17U && access != 18U)
            throw new ArgumentException("Unsupported enumeration access type");
        var result = new List<string>();
        IntPtr s = IntPtr.Zero, g = IntPtr.Zero;
        try {
            s = GuidPointer(scheme);
            g = GuidPointer(subgroup);
            for (uint i=0; i < 8192U; ++i) {
                byte[] bytes = new byte[16]; uint length = 16U;
                uint err = PowerEnumerate(IntPtr.Zero, s, g, access, i, bytes, ref length);
                if (err == 259U) break; // ERROR_NO_MORE_ITEMS
                if (err != 0U || length != 16U) break; // partial enumeration is not treated as proof of absence
                result.Add(new Guid(bytes).ToString("D"));
            }
        } finally { Free(ref g); Free(ref s); }
        return result.ToArray();
    }
    private static uint CallText(string kind, IntPtr s, IntPtr g, IntPtr p, uint index, byte[] buffer, ref uint size) {
        switch (kind) {
            case "name": return PowerReadFriendlyName(IntPtr.Zero, s, g, p, buffer, ref size);
            case "description": return PowerReadDescription(IntPtr.Zero, s, g, p, buffer, ref size);
            case "units": return PowerReadValueUnitsSpecifier(IntPtr.Zero, g, p, buffer, ref size);
            case "optionName": return PowerReadPossibleFriendlyName(IntPtr.Zero, g, p, index, buffer, ref size);
            case "optionDescription": return PowerReadPossibleDescription(IntPtr.Zero, g, p, index, buffer, ref size);
            default: throw new ArgumentException("Unknown native string type");
        }
    }
    public static string Text(string kind, string scheme, string subgroup, string setting, uint optionIndex) {
        IntPtr s = IntPtr.Zero, g = IntPtr.Zero, p = IntPtr.Zero;
        try {
            s = GuidPointer(scheme); g = GuidPointer(subgroup); p = GuidPointer(setting);
            uint length = 0U;
            uint result = CallText(kind, s, g, p, optionIndex, null, ref length);
            if (result != 0U || length < 2U || length > 65536U || length % 2U != 0U) return null;
            byte[] buffer = new byte[(int)length];
            result = CallText(kind, s, g, p, optionIndex, buffer, ref length);
            if (result != 0U) return null;
            string txt = Encoding.Unicode.GetString(buffer, 0, (int)length).TrimEnd('\0');
            return String.IsNullOrWhiteSpace(txt) ? null : txt;
        } finally { Free(ref p); Free(ref g); Free(ref s); }
    }
    public static long Number(string kind, string subgroup, string setting) {
        IntPtr g = IntPtr.Zero, p = IntPtr.Zero;
        try {
            g = GuidPointer(subgroup); p = GuidPointer(setting);
            uint value; uint err;
            switch (kind) {
                case "min": err = PowerReadValueMin(IntPtr.Zero, g, p, out value); break;
                case "max": err = PowerReadValueMax(IntPtr.Zero, g, p, out value); break;
                case "step": err = PowerReadValueIncrement(IntPtr.Zero, g, p, out value); break;
                default: throw new ArgumentException("Unknown native numeric type");
            }
            return err == 0U ? (long)value : -1L;
        } finally { Free(ref p); Free(ref g); }
    }
    public static PowerExplorerChoice[] Choices(string subgroup, string setting) {
        var result = new List<PowerExplorerChoice>();
        IntPtr g = IntPtr.Zero, p = IntPtr.Zero;
        try {
            g = GuidPointer(subgroup); p = GuidPointer(setting);
            // Possible-setting indexes are zero-based. Stop at the first unavailable
            // index (the API does not publish an enumeration/count API for choices).
            for (uint i=0U; i<256U; ++i) {
                uint dataType, size = 0U;
                uint err = PowerReadPossibleValue(IntPtr.Zero, g, p, out dataType, i, null, ref size);
                if (err != 0U || size != 4U || dataType != 4U) break; // REG_DWORD choices only
                byte[] bytes = new byte[4];
                err = PowerReadPossibleValue(IntPtr.Zero, g, p, out dataType, i, bytes, ref size);
                if (err != 0U || size != 4U || dataType != 4U) break;
                var choice = new PowerExplorerChoice();
                choice.Index = i; choice.Value = (long)BitConverter.ToUInt32(bytes, 0);
                result.Add(choice);
            }
        } finally { Free(ref p); Free(ref g); }
        foreach (PowerExplorerChoice c in result) {
            c.Name = Text("optionName", null, subgroup, setting, c.Index);
            c.Description = Text("optionDescription", null, subgroup, setting, c.Index);
        }
        return result.ToArray();
    }
    public static long ReadValue(string scheme, string subgroup, string setting, bool dc) {
        Guid a = new Guid(scheme), b = new Guid(subgroup), c = new Guid(setting);
        uint value = 0U;
        uint code = dc ? PowerReadDCValueIndex(IntPtr.Zero, ref a, ref b, ref c, out value)
                       : PowerReadACValueIndex(IntPtr.Zero, ref a, ref b, ref c, out value);
        return code == 0U ? (long)value : -1L;
    }
    public static bool Hidden(string subgroup, string setting) {
        Guid g = new Guid(subgroup), p = new Guid(setting);
        return (PowerReadSettingAttributes(ref g, ref p) & 1U) != 0U;
    }
    public static string Localize(string source) {
        if (String.IsNullOrWhiteSpace(source) || !source.StartsWith("@")) return source;
        var outText = new StringBuilder(2048);
        string expanded = Environment.ExpandEnvironmentVariables(source);
        return SHLoadIndirectString(expanded, outText, (uint)outText.Capacity, IntPtr.Zero) == 0
            ? outText.ToString() : source;
    }
}
'@ -ErrorAction Stop

$script:GuidPattern = '[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}'
$script:GuidOnly = '^' + $script:GuidPattern + '$'
$script:PowerRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings'
$script:Settings = @()
$script:Devices = @()
$script:Groups = @{}
$script:Selected = $null
$script:PlanId = $null
$script:ActivePlanId = $null
$script:BackupPath = $null
$script:BackupScheme = $null
$script:Reloading = $false
$script:DeviceLoaded = $false
$script:CollectionBusy = $false
$script:Plans = @(); $script:PolicyLocks = @{}
$script:NativeNames = 0; $script:RegistryNames = 0; $script:NativeOptions = 0
$script:SleepInfo = ''; $script:WakeInfo = ''; $script:ProgrammableWakeInfo = ''; $script:RequestsInfo = ''
$script:DevicePropertyCache = @{}
$script:CollectionStates = @{
    Plans = 'Not collected'; Devices = 'Not collected'; 'Device properties' = 'Not read'
}
$script:CollectionCompletedAt = @{}
$script:Reference = @{}
$script:CategoryReference = @{}
$script:DeviceReference = @{}
$script:SelectedSourceUrl = $null
$script:SelectedPolicy = $false
$script:DeviceSourceUrl = $null
$script:KnowledgeFile = Join-Path $PSScriptRoot 'PowerExplorer_Knowledge.json'
$script:KnowledgeStatus = 'Reference data not loaded'
function Load-Knowledge {
    if (!(Test-Path -LiteralPath $script:KnowledgeFile)) {
        $script:KnowledgeStatus = 'Knowledge file absent; Windows local data still available.'
        return
    }
    try {
        $data = Get-Content -LiteralPath $script:KnowledgeFile -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        if ($data.schema -ne 'power-explorer-knowledge/v1') {
            throw "Unsupported knowledge file schema: $($data.schema)"
        }
        foreach ($entry in $data.settings) {
            if ([string]$entry.guid -match ('^' + '[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}' + '$')) {
                $script:Reference[([string]$entry.guid).ToLowerInvariant()] = $entry
            }
        }
        foreach ($entry in $data.categories) { $script:CategoryReference[[string]$entry.name] = $entry }
        foreach ($entry in $data.deviceClasses) { $script:DeviceReference[[string]$entry.class] = $entry }
        $script:KnowledgeStatus = "Microsoft Learn reference notes: $($script:Reference.Count) GUID-matched settings, $($script:DeviceReference.Count) device classes."
    } catch {
        $script:KnowledgeStatus = "Reference data not loaded: $($_.Exception.Message)"
    }
}
Load-Knowledge
$script:CategoryMap = @{
    '54533251-82be-4824-96c1-47b60b740d00' = 'CPU & performance'
    '0012ee47-9041-4b5d-9b77-535fba8b1442' = 'Storage & disks'
    '7516b95f-f776-4464-8c53-06167f40cc99' = 'Display & graphics'
    '238c9fa8-0aad-41ed-83f4-97be242c8f20' = 'Sleep & hibernation'
    '2a737441-1930-4402-8d77-b2bebba308a3' = 'USB & peripherals'
    '501a4d13-42af-4429-9fd1-a8218c268e20' = 'PCI Express'
    'e73a048d-bf27-4f12-9731-8b2076e8891f' = 'Battery'
    '4f971e89-eebd-4455-a8de-9e59040e7347' = 'Power buttons & lid'
    'fea3413e-7e05-4911-9a71-700331f1c294' = 'General system'
    '19cbb8fa-5279-450e-9fac-8a3d5fedd0c1' = 'Network & connectivity'
    '9596fb26-9850-41fd-ac3e-f7c3c00afd4b' = 'Media & playback'
}
$script:CategoryOrder = @(
    'CPU & performance', 'Sleep & hibernation', 'Display & graphics',
    'Storage & disks', 'USB & peripherals', 'PCI Express',
    'Network & connectivity', 'Media & playback', 'Battery', 'Power buttons & lid',
    'General system', 'Other settings'
)

function Run-PowerCfg {
    param([string[]]$Arguments)
    $output = & "$env:SystemRoot\System32\powercfg.exe" @Arguments 2>&1 | Out-String
    $exit = $LASTEXITCODE
    [pscustomobject]@{ OK = ($exit -eq 0); Exit = $exit; Text = $output.Trim() }
}
function RegistryProps([string]$Path) {
    Get-ItemProperty -LiteralPath $Path -ErrorAction SilentlyContinue
}
function Resolve-Text([object]$InputText, [string]$Fallback) {
    if ($null -eq $InputText) { return $Fallback }
    $plain = [string]$InputText
    if ([string]::IsNullOrWhiteSpace($plain)) { return $Fallback }
    $resolved = [PowerExplorerNative]::Localize($plain)
    if ($resolved.StartsWith('@')) { return $Fallback }
    return $resolved
}
function Classify-Group([string]$Id, [string]$Name) {
    $key = $Id.ToLowerInvariant()
    if ($script:CategoryMap.ContainsKey($key)) { return $script:CategoryMap[$key] }
    switch -Regex ($Name) {
        'processor|cpu|performance' { return 'CPU & performance' }
        'wireless|network|ethernet|wi-fi|wifi' { return 'Network & connectivity' }
        'usb|peripheral' { return 'USB & peripherals' }
        'video|display|graphics' { return 'Display & graphics' }
        'disk|storage|hard drive' { return 'Storage & disks' }
        'sleep|hibernate' { return 'Sleep & hibernation' }
        'pci|express' { return 'PCI Express' }
        'battery' { return 'Battery' }
        'multimedia|media|video playback' { return 'Media & playback' }
        'button|lid' { return 'Power buttons & lid' }
        default { return 'Other settings' }
    }
}
function Get-ActivePlan {
    $output = Run-PowerCfg -Arguments @('/getactivescheme')
    $matched = [regex]::Match($output.Text, $script:GuidPattern)
    if (!$output.OK -or !$matched.Success) {
        throw "Cannot read active power scheme: $($output.Text)"
    }
    return $matched.Value.ToLowerInvariant()
}
function Read-Plans {
    $script:ActivePlanId = Get-ActivePlan
    $output = Run-PowerCfg -Arguments @('/list')
    # The native scheme list and names are preferred; text parsing is only fallback.
    $ids = New-Object System.Collections.Generic.List[string]
    foreach ($id in @([PowerExplorerNative]::Enumerate('', '', 16))) {
        if (!$ids.Contains($id)) { $ids.Add($id) }
    }
    if ($output.OK) {
        foreach ($line in ($output.Text -split "`r?`n")) {
            if ($line -match $script:GuidPattern) {
                $id = $Matches[0].ToLowerInvariant()
                if (!$ids.Contains($id)) { $ids.Add($id) }
            }
        }
    }
    if (!$ids.Contains($script:ActivePlanId)) { $ids.Add($script:ActivePlanId) }
    $plans = @()
    foreach ($id in $ids) {
        $name = [PowerExplorerNative]::Text('name', $id, '', '', 0)
        if ([string]::IsNullOrWhiteSpace($name) -and $output.OK) {
            foreach ($line in ($output.Text -split "`r?`n")) {
                if ($line -match [regex]::Escape($id) -and $line -match '\(([^()]*)\)') {
                    $name = $Matches[1]; break
                }
            }
        }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = $id }
        $isActive = ($id -eq $script:ActivePlanId)
        $plans += [pscustomobject]@{
            Id = $id; Name = $name
            Label = $(if ($isActive) { "$name  [active]" } else { $name })
        }
    }
    return $plans
}
function Uint32-FromRaw([object]$Raw) {
    if ($null -eq $Raw) { return $null }
    try {
        if ($Raw -is [byte[]]) {
            if ($Raw.Length -eq 4) { return [long][BitConverter]::ToUInt32($Raw, 0) }
            return $null
        }
        $value = [long]$Raw
        if ($value -lt 0 -and $value -ge -2147483648) { $value += 4294967296 }
        if ($value -lt 0 -or $value -gt 4294967295) { return $null }
        return $value
    } catch { return $null }
}
function Load-Settings {
    $all = New-Object System.Collections.Generic.List[object]
    $script:Groups = @{}
    $script:NativeNames = 0
    $script:RegistryNames = 0
    $script:NativeOptions = 0
    $groupIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $nativeGroupIds = @([PowerExplorerNative]::Enumerate($script:PlanId, '', 17))
    foreach ($id in $nativeGroupIds) { [void]$groupIds.Add($id) }
    # Union with local registry definitions so hidden/unpopulated settings are not lost.
    foreach ($groupKey in @(Get-ChildItem -LiteralPath $script:PowerRoot -ErrorAction SilentlyContinue)) {
        if ($groupKey.PSChildName -match $script:GuidOnly) {
            [void]$groupIds.Add($groupKey.PSChildName.ToLowerInvariant())
        }
    }
    foreach ($groupId in @($groupIds | Sort-Object)) {
        $groupPath = Join-Path $script:PowerRoot $groupId
        $groupProps = RegistryProps $groupPath
        $apiGroupName = [PowerExplorerNative]::Text('name', $script:PlanId, $groupId, '', 0)
        $groupName = if (![string]::IsNullOrWhiteSpace($apiGroupName)) { $apiGroupName } else {
            Resolve-Text $groupProps.FriendlyName $groupId
        }
        $category = Classify-Group $groupId $groupName
        $script:Groups[$groupId] = [pscustomobject]@{
            Id = $groupId; Name = $groupName; Category = $category
        }
        $settingIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($id in @([PowerExplorerNative]::Enumerate($script:PlanId, $groupId, 18))) {
            [void]$settingIds.Add($id)
        }
        foreach ($settingKey in @(Get-ChildItem -LiteralPath $groupPath -ErrorAction SilentlyContinue)) {
            if ($settingKey.PSChildName -match $script:GuidOnly) {
                [void]$settingIds.Add($settingKey.PSChildName.ToLowerInvariant())
            }
        }
        foreach ($settingId in @($settingIds | Sort-Object)) {
            $settingPath = Join-Path $groupPath $settingId
            $p = RegistryProps $settingPath
            $apiName = [PowerExplorerNative]::Text('name', $script:PlanId, $groupId, $settingId, 0)
            $apiDesc = [PowerExplorerNative]::Text('description', $script:PlanId, $groupId, $settingId, 0)
            $name = if (![string]::IsNullOrWhiteSpace($apiName)) { $apiName } else {
                Resolve-Text $p.FriendlyName $settingId
            }
            $description = if (![string]::IsNullOrWhiteSpace($apiDesc)) { $apiDesc } else {
                Resolve-Text $p.Description 'No description supplied by Windows or the driver.'
            }
            $nameSource = if (![string]::IsNullOrWhiteSpace($apiName)) {
                $script:NativeNames++; 'PowrProf.dll'
            } elseif ($name -ne $settingId) {
                $script:RegistryNames++; 'Registry resource'
            } else { 'GUID fallback' }

            $opts = New-Object System.Collections.Generic.List[object]
            $nativeChoices = @([PowerExplorerNative]::Choices($groupId, $settingId))
            if ($nativeChoices.Count -gt 0) {
                foreach ($choice in $nativeChoices) {
                    $label = if (![string]::IsNullOrWhiteSpace($choice.Name)) { $choice.Name } else { "Option $($choice.Index)" }
                    $opts.Add([pscustomobject]@{
                        Value = [long]$choice.Value; Name = $label; Description = [string]$choice.Description
                    })
                }
                $script:NativeOptions++
            } else {
                foreach ($optKey in @(Get-ChildItem -LiteralPath $settingPath -ErrorAction SilentlyContinue)) {
                    if ($optKey.PSChildName -notmatch '^\d+$') { continue }
                    $op = RegistryProps $optKey.PSPath
                    $rawValue = Uint32-FromRaw $op.SettingValue
                    if ($null -eq $rawValue) { continue }
                    $label = Resolve-Text $op.FriendlyName "Option $($optKey.PSChildName)"
                    $opts.Add([pscustomobject]@{ Value = $rawValue; Name = $label; Description = '' })
                }
            }
            $low = [PowerExplorerNative]::Number('min', $groupId, $settingId)
            $high = [PowerExplorerNative]::Number('max', $groupId, $settingId)
            $step = [PowerExplorerNative]::Number('step', $groupId, $settingId)
            if ($low -lt 0) { $low = Uint32-FromRaw $p.ValueMin }
            if ($high -lt 0) { $high = Uint32-FromRaw $p.ValueMax }
            if ($step -lt 0) { $step = Uint32-FromRaw $p.ValueIncrement }
            $unitApi = [PowerExplorerNative]::Text('units', '', $groupId, $settingId, 0)
            $units = if (![string]::IsNullOrWhiteSpace($unitApi)) { $unitApi } else {
                Resolve-Text $p.ValueUnits ''
            }
            $hidden = [PowerExplorerNative]::Hidden($groupId, $settingId)
            $all.Add([pscustomobject]@{
                Id = $settingId; GroupId = $groupId; Name = $name
                Description = $description; Group = $groupName; Category = $category
                Hidden = $hidden; Options = @($opts.ToArray())
                Min = $low; Max = $high; Increment = $step; Units = $units
                NameSource = $nameSource
                DescriptionSource = $(if ($apiDesc) { 'PowrProf.dll' } else { 'Registry/fallback' })
                ChoiceSource = $(if ($nativeChoices.Count -gt 0) { 'PowrProf.dll' } else { 'Registry/fallback' })
                AC = [long]-1; DC = [long]-1
            })
        }
    }
    $script:Settings = @($all.ToArray())
}
function Read-Values {
    foreach ($s in $script:Settings) {
        $s.AC = [PowerExplorerNative]::ReadValue($script:PlanId, $s.GroupId, $s.Id, $false)
        $s.DC = [PowerExplorerNative]::ReadValue($script:PlanId, $s.GroupId, $s.Id, $true)
    }
}
function Describe-Value([object]$S, [long]$Value) {
    if ($Value -lt 0) { return 'not exposed' }
    foreach ($opt in $S.Options) {
        if ($opt.Value -eq $Value) { return "$($opt.Name) ($Value)" }
    }
    if ($S.Units) { return "$Value $($S.Units)" }
    return [string]$Value
}
function Has-Validation([object]$S) {
    if ($S.Options.Count -gt 0) { return $true }
    return ($null -ne $S.Min -and $null -ne $S.Max -and
            $null -ne $S.Increment -and $S.Increment -gt 0 -and $S.Min -le $S.Max)
}
function Check-Value([object]$S, [long]$Value) {
    if ($Value -lt 0 -or $Value -gt 4294967295) { return $false }
    if ($S.Options.Count -gt 0) {
        return (@($S.Options | Where-Object { $_.Value -eq $Value }).Count -gt 0)
    }
    if (!(Has-Validation $S)) { return $false }
    return ($Value -ge $S.Min -and $Value -le $S.Max -and
            (($Value - $S.Min) % $S.Increment) -eq 0)
}
function Alert([string]$Message, [string]$Title = 'Power Explorer') {
    [System.Windows.Forms.MessageBox]::Show(
        $script:MainForm, $Message, $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}
function Update-Status([string]$Message) { $script:StatusLabel.Text = $Message }
function Update-PowerBrowseStatus {
    if ($script:Tabs.SelectedTab -eq $tabDevices) {
        $script:StatusLabel.Text = $(if ($script:DeviceLoaded) {
            "$($script:DeviceGrid.Rows.Count) shown / $($script:Devices.Count) collected devices."
        } else { 'Devices: not collected' })
    } else {
        $script:StatusLabel.Text = $(if ($script:PlanId) {
            "$($script:Grid.Rows.Count) shown / $($script:Settings.Count) settings; $($script:NativeNames) named via Windows API, $($script:RegistryNames) via registry."
        } else { 'Power plans: not collected' })
    }
}
. (Join-Path $PSScriptRoot 'PowerExplorer_UI.ps1')

function Refresh-Tree {
    $script:Tree.BeginUpdate()
    try {
        $script:Tree.Nodes.Clear()
        $visible = @($script:Settings | Where-Object { $script:ShowHidden.Checked -or !$_.Hidden })
        $root = New-Object System.Windows.Forms.TreeNode("All settings ($($visible.Count))")
        $root.Tag = @{ Category = '*'; Group = '*' }
        [void]$script:Tree.Nodes.Add($root)
        foreach ($category in $script:CategoryOrder) {
            $members = @($visible | Where-Object { $_.Category -eq $category })
            if ($members.Count -eq 0) { continue }
            $catNode = New-Object System.Windows.Forms.TreeNode("$category ($($members.Count))")
            $catNode.Tag = @{ Category = $category; Group = '*' }
            [void]$root.Nodes.Add($catNode)
            foreach ($group in @($script:Groups.Values | Where-Object { $_.Category -eq $category } | Sort-Object Name)) {
                $count = @($members | Where-Object { $_.GroupId -eq $group.Id }).Count
                if ($count -lt 1) { continue }
                $node = New-Object System.Windows.Forms.TreeNode("$($group.Name) ($count)")
                $node.Tag = @{ Category = $category; Group = $group.Id }
                [void]$catNode.Nodes.Add($node)
            }
        }
        $root.Expand()
        $script:Tree.SelectedNode = $root
        $script:Tree.TopNode = $root
    } finally { $script:Tree.EndUpdate() }
}
function Refresh-Grid {
    $script:Grid.Rows.Clear()
    $tag = if ($script:Tree.SelectedNode) { $script:Tree.SelectedNode.Tag } else { @{ Category='*'; Group='*' } }
    $needle = $script:Search.Text.Trim()
    $items = @($script:Settings | Where-Object {
        $reference = $script:Reference[$_.Id]
        ($script:ShowHidden.Checked -or !$_.Hidden) -and
        ($tag.Category -eq '*' -or $_.Category -eq $tag.Category) -and
        ($tag.Group -eq '*' -or $_.GroupId -eq $tag.Group) -and
        (!$needle -or $_.Name.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
         $_.Description.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
         $_.Group.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
         ($null -ne $reference -and (
              ([string]$reference.summary).IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
              ([string]$reference.alias).IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)))
    } | Sort-Object Name)
    foreach ($s in $items) {
        $index = $script:Grid.Rows.Add(
            $s.Name, (Describe-Value $s $s.AC), (Describe-Value $s $s.DC),
            $(if ($s.Hidden) { 'Hidden' } else { 'Visible' })
        )
        $script:Grid.Rows[$index].Tag = $s
        if ($s.Hidden) {
            $script:Grid.Rows[$index].DefaultCellStyle.ForeColor = [System.Drawing.Color]::DimGray
        }
    }
    Update-PowerBrowseStatus
    if ($script:Grid.Rows.Count -gt 0) {
        $script:Grid.Rows[0].Selected = $true
        Show-SelectedSetting $script:Grid.Rows[0].Tag
    } else { Show-SelectedSetting $null }
}
function Set-EditorValue($Combo, $Numeric, [object]$S, [long]$Value) {
    $Combo.Visible = ($S.Options.Count -gt 0)
    $Numeric.Visible = ($S.Options.Count -eq 0)
    $Combo.Items.Clear()
    $Combo.Tag = @{}
    if ($S.Options.Count -gt 0) {
        $seen = @{}
        foreach ($option in ($S.Options | Sort-Object Value)) {
            $label = "$($option.Name) ($($option.Value))"
            if ($seen.ContainsKey($label)) {
                $seen[$label] = [int]$seen[$label] + 1
                $label += " [entry $($seen[$label])]"
            } else { $seen[$label] = 1 }
            [void]$Combo.Items.Add($label)
            $Combo.Tag[$label] = [long]$option.Value
            if ($Value -eq $option.Value -and $null -eq $Combo.SelectedItem) {
                $Combo.SelectedItem = $label
            }
        }
    } elseif (Has-Validation $S) {
        $Numeric.Minimum = [decimal]$S.Min
        $Numeric.Maximum = [decimal]$S.Max
        $Numeric.Increment = [decimal]$S.Increment
        if ($Value -ge $S.Min -and $Value -le $S.Max) {
            $Numeric.Value = [decimal]$Value
        } else { $Numeric.Value = [decimal]$S.Min }
    }
}
function Get-ReferenceUrl([object]$Entry) {
    if ($null -ne $Entry -and [string]$Entry.url -match '^https://learn\.microsoft\.com/') {
        return [string]$Entry.url
    }
    return $null
}
function Open-ReferenceUrl([string]$Url) {
    if (!$Url -or $Url -notmatch '^https://learn\.microsoft\.com/') { return }
    try { Start-Process $Url -ErrorAction Stop }
    catch { Alert $_.Exception.Message 'Could not open documentation' }
}
function Show-SelectedSetting([object]$S) {
    $script:Selected = $S
    $script:SelectedSourceUrl = $null
    $script:SelectedPolicy = $false
    $script:DocsButton.Enabled = $false
    if ($null -eq $S) {
        $script:DetailTitle.Text = 'Select a power setting'
        $script:DetailText.Clear(); $script:EvidenceText.Clear()
        foreach ($c in @($script:AcCombo,$script:DcCombo,$script:AcNumber,$script:DcNumber)) { $c.Visible = $false }
        $script:SaveButton.Enabled = $false
        return
    }
    $script:DetailTitle.Text = $S.Name
    $ref = $script:Reference[$S.Id]
    $categoryRef = $script:CategoryReference[$S.Category]
    $script:SelectedSourceUrl = Get-ReferenceUrl $ref
    if (!$script:SelectedSourceUrl) { $script:SelectedSourceUrl = Get-ReferenceUrl $categoryRef }
    $script:DocsButton.Enabled = [bool]$script:SelectedSourceUrl
    $referenceText = ''
    if ($ref) {
        $referenceText = "`r`n`r`nMICROSOFT REFERENCE (curated; not a hardware-support assertion):`r`n" +
            "$($ref.summary)`r`nPowercfg alias: $($ref.alias)`r`nCaution: $($ref.caution)`r`nSource: $($ref.url)"
    } elseif ($categoryRef) {
        $referenceText = "`r`n`r`nCATEGORY GUIDANCE (not specific to this setting):`r`n" +
            "$($categoryRef.summary)`r`nSource: $($categoryRef.url)"
    }
    # Education/enterprise policy may override the value stored in a power plan.
    # Presence of policy indices is treated as a conservative editing lock.
    $script:SelectedPolicy = (!$script:PolicyLocks.ContainsKey($S.Id) -or $script:PolicyLocks[$S.Id])
    if ($script:SelectedPolicy) {
        $referenceText += "`r`n`r`nPOLICY: Editing disabled because a policy override was observed or a policy check is unavailable in this snapshot."
    }
    $optionNotes = ''
    if ($S.Options.Count -gt 0) {
        $choiceLines = @($S.Options | Sort-Object Value | Select-Object -First 30 | ForEach-Object {
            $line = "  $($_.Value): $($_.Name)"
            if ($_.Description) { $line += " - $($_.Description)" }
            $line
        })
        $optionNotes = "`r`n`r`nWINDOWS ENUMERATED CHOICES ($($S.Options.Count); source: $($S.ChoiceSource)):`r`n" +
            ($choiceLines -join "`r`n")
        if ($S.Options.Count -gt 30) { $optionNotes += "`r`n  ... additional options omitted from details" }
    } elseif (Has-Validation $S) {
        $optionNotes = "`r`n`r`nWINDOWS NUMERIC RANGE: $($S.Min) to $($S.Max), step $($S.Increment), units: $($S.Units)"
    }
    Set-SectionText $script:DetailText 'Windows description' ([string]$S.Description)
    $script:EvidenceText.Text = "Category: $($S.Category) | Windows subgroup: $($S.Group)`r`n" +
        "Setting GUID: $($S.Id)`r`nGroup GUID: $($S.GroupId)`r`n" +
        "Windows visibility: $(if ($S.Hidden) { 'hidden' } else { 'visible' }) " +
        '(visibility is not a hardware-support test)' +
        "`r`nName source: $($S.NameSource); description source: $($S.DescriptionSource)" +
        $optionNotes + $referenceText
    Set-EditorValue $script:AcCombo $script:AcNumber $S $S.AC
    Set-EditorValue $script:DcCombo $script:DcNumber $S $S.DC
    $allow = ($script:AllowEdit.Checked -and !$script:SelectedPolicy -and (Has-Validation $S) -and
              (Check-Value $S $S.AC) -and (Check-Value $S $S.DC))
    $script:SaveButton.Enabled = $allow
    foreach ($c in @($script:AcCombo,$script:DcCombo,$script:AcNumber,$script:DcNumber)) { $c.Enabled = $allow }
    if ($script:SelectedPolicy) {
        $script:EditInfo.Text = 'Read-only: policy override observed or policy check unavailable in this snapshot.'
    } elseif (!(Has-Validation $S)) {
        $script:EditInfo.Text = 'Read-only: this setting does not publish verifiable choices or numeric bounds.'
    } elseif ($S.AC -lt 0 -or $S.DC -lt 0) {
        $script:EditInfo.Text = 'Read-only: the selected plan does not expose both AC and DC indices.'
    } elseif (!(Check-Value $S $S.AC) -or !(Check-Value $S $S.DC)) {
        $script:EditInfo.Text = 'Read-only: current values lie outside the published choices or bounds.'
    } else {
        $script:EditInfo.Text = $(if ($script:AllowEdit.Checked) {
            'Changing values requires confirmation and an exported .pow backup.'
        } else {
            'Enable editing to change supported numeric or enumerated settings.'
        })
    }
}
function Get-EditorValue($Combo, $Numeric, [object]$S) {
    if ($S.Options.Count -gt 0) {
        if ($null -eq $Combo.SelectedItem) { return $null }
        return [long]$Combo.Tag[[string]$Combo.SelectedItem]
    }
    return [long]$Numeric.Value
}
function Make-Backup {
    if (!$script:PlanId) { throw 'No power plan selected.' }
    $folder = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerExplorerBackups'
    New-Item -Path $folder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    $path = Join-Path $folder ("plan-$($script:PlanId)-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff').pow")
    $result = Run-PowerCfg -Arguments @('/export', $path, $script:PlanId)
    if (!$result.OK -or !(Test-Path -LiteralPath $path)) {
        throw "Could not back up plan. $($result.Text)"
    }
    $script:BackupPath = $path
    $script:BackupScheme = $script:PlanId
    return $path
}
function Export-Catalog {
    if (!$script:PlanId -or $script:Settings.Count -eq 0) { throw 'No settings catalog loaded.' }
    $save = New-Object System.Windows.Forms.SaveFileDialog
    $save.Title = 'Export Windows power setting catalog'
    $save.Filter = 'JSON catalog (*.json)|*.json|All files (*.*)|*.*'
    $save.FileName = 'power-catalog-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json'
    $save.InitialDirectory = [Environment]::GetFolderPath('MyDocuments')
    try {
        if ($save.ShowDialog($script:MainForm) -ne [System.Windows.Forms.DialogResult]::OK) { return }
        $document = [ordered]@{
            schema = 'power-explorer-local-catalog/v1'
            createdUtc = [DateTime]::UtcNow.ToString('o')
            computerName = $env:COMPUTERNAME
            selectedScheme = $script:PlanId
            activeScheme = $script:ActivePlanId
            sources = @('PowrProf.dll', 'HKLM PowerSettings', 'powercfg (plan values)')
            warning = 'A registered value does not prove device or firmware support; AC/DC indices are scheme configuration.'
            discoveredSettingCount = $script:Settings.Count
            nativeNameCount = $script:NativeNames
            settings = @($script:Settings | Sort-Object Category, Group, Name)
        }
        $json = ConvertTo-Json -InputObject $document -Depth 8
        [System.IO.File]::WriteAllText($save.FileName, $json, (New-Object System.Text.UTF8Encoding($false)))
        Alert "Local setting catalog saved:`r`n$($save.FileName)`r`n`r`nThis is a read-only export; no power settings were changed."
    } finally { $save.Dispose() }
}

function Set-PowerCollectionStage([string]$Message) {
    $body = ($script:CollectionStates.GetEnumerator() | Sort-Object Name | ForEach-Object { $_.Name + ': ' + $_.Value }) -join "`r`n"
    Set-SectionText $script:CollectionText $Message $body
    $script:MainForm.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}
function Publish-PlanSnapshot {
    $script:PlansCombo.Items.Clear()
    foreach ($plan in $script:Plans) { [void]$script:PlansCombo.Items.Add($plan) }
    foreach ($plan in $script:PlansCombo.Items) {
        if ($plan.Id -eq $script:PlanId) { $script:PlansCombo.SelectedItem = $plan; break }
    }
    Refresh-Tree
}
function Invoke-PowerRead([string]$Scope, [scriptblock]$Collect, [scriptblock]$Publish) {
    if ($script:CollectionBusy) { return }
    $ErrorActionPreference = 'Stop'
    $names = @('Settings','Groups','PlanId','ActivePlanId','Plans','PolicyLocks','NativeNames','RegistryNames',
        'NativeOptions','Devices','DeviceLoaded','DevicePropertyCache','SleepInfo','WakeInfo','ProgrammableWakeInfo','RequestsInfo')
    $previous = @{}
    foreach ($name in $names) { $previous[$name] = Get-Variable -Name $name -Scope Script -ValueOnly }
    $previousSelection = $script:Selected
    $script:CollectionBusy = $true; $script:Reloading = $true
    $script:AllowEdit.Checked = $false
    $script:Tabs.Enabled = $false; $script:MainForm.ControlBox = $false
    $script:CollectionStates[$Scope] = 'Collecting; previous completed snapshot retained until success'
    try {
        Set-PowerCollectionStage ("Collecting: $Scope")
        & $Collect
        & $Publish
        $script:CollectionCompletedAt[$Scope] = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
        $script:CollectionStates[$Scope] = 'Completed at ' + $script:CollectionCompletedAt[$Scope]
        Set-PowerCollectionStage ("Completed: $Scope")
    } catch {
        $message = $_.Exception.Message
        foreach ($name in $names) { Set-Variable -Name $name -Scope Script -Value $previous[$name] }
        if ($Scope -eq 'Plans') { Publish-PlanSnapshot; Show-SelectedSetting $previousSelection }
        $last = $(if ($script:CollectionCompletedAt.ContainsKey($Scope)) { $script:CollectionCompletedAt[$Scope] } else { 'none' })
        $script:CollectionStates[$Scope] = "Failed: $message | Last completed: $last"
        Set-PowerCollectionStage ("Failed: $Scope; previous snapshot retained")
    } finally {
        $script:Reloading = $false; $script:CollectionBusy = $false
        $script:Tabs.Enabled = $true; $script:MainForm.ControlBox = $true
        $hasPlan = ![string]::IsNullOrEmpty($script:PlanId) -and $script:Settings.Count -gt 0
        $backupPlan.Enabled = $hasPlan; $exportCatalog.Enabled = $hasPlan
        $script:AllowEdit.Enabled = ($hasPlan -and $script:CollectionStates.Plans -like 'Completed*')
    }
}
function Refresh-PlansAndSettings([string]$RequestedPlan = '') {
    Invoke-PowerRead 'Plans' {
        $previousPlan = $(if ($RequestedPlan) { $RequestedPlan } else { $script:PlanId })
        Set-PowerCollectionStage 'Reading available power plans'
        $script:Plans = @(Read-Plans)
        $chosen = @($script:Plans | Where-Object { $_.Id -eq $previousPlan } | Select-Object -First 1)
        if (!$chosen.Count) { $chosen = @($script:Plans | Where-Object { $_.Id -eq $script:ActivePlanId } | Select-Object -First 1) }
        if (!$chosen.Count) { throw 'No power scheme found.' }
        $script:PlanId = $chosen[0].Id
        Set-PowerCollectionStage 'Reading setting definitions and choices'
        Load-Settings
        Set-PowerCollectionStage 'Reading AC/DC values and policy indicators'
        Read-Values
        $script:PolicyLocks = @{}
        foreach ($setting in $script:Settings) {
            $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\' + $setting.Id
            $locked = $false
            try {
                if (Test-Path -LiteralPath $path -ErrorAction Stop) {
                    $policy = Get-ItemProperty -LiteralPath $path -ErrorAction Stop
                    $locked = ($null -eq $policy -or $null -ne $policy.ACSettingIndex -or $null -ne $policy.DCSettingIndex)
                }
            } catch { $locked = $true } # An unreadable policy check must not enable editing.
            $script:PolicyLocks[$setting.Id] = $locked
        }
    } { Publish-PlanSnapshot }
}

$script:Tree.Add_AfterSelect({ Refresh-Grid })
$script:Search.Add_TextChanged({ Refresh-Grid })
$script:ShowHidden.Add_CheckedChanged({ Refresh-Tree })
$script:Grid.Add_SelectionChanged({
    if ($script:Grid.SelectedRows.Count -eq 1) {
        Show-SelectedSetting $script:Grid.SelectedRows[0].Tag
    }
})
$script:AllowEdit.Add_CheckedChanged({
    Update-EditingIndicator
    Show-SelectedSetting $script:Selected
})
$script:PlansCombo.Add_SelectedIndexChanged({
    if ($script:Reloading -or $script:CollectionBusy -or !$script:PlansCombo.SelectedItem) { return }
    Refresh-PlansAndSettings ([string]$script:PlansCombo.SelectedItem.Id)
})
$refreshPlan.Add_Click({
    try { Refresh-PlansAndSettings }
    catch { Alert $_.Exception.Message 'Refresh failed' }
})
$exportCatalog.Add_Click({
    try { Export-Catalog } catch { Alert $_.Exception.Message 'Catalog export failed' }
})
$backupPlan.Add_Click({
    try {
        $path = Make-Backup
        Alert "Power scheme exported to:`r`n$path`r`n`r`nTo restore, use powercfg /import (creates an imported scheme)."
    } catch { Alert $_.Exception.Message 'Backup failed' }
})
$openAdvanced.Add_Click({ Start-Process control.exe -ArgumentList 'powercfg.cpl,,3' })
$script:DocsButton.Add_Click({ Open-ReferenceUrl $script:SelectedSourceUrl })
$script:SaveButton.Add_Click({
    $s = $script:Selected
    if (!$script:AllowEdit.Checked -or $script:SelectedPolicy -or $null -eq $s -or !(Has-Validation $s)) { return }
    $newAc = Get-EditorValue $script:AcCombo $script:AcNumber $s
    $newDc = Get-EditorValue $script:DcCombo $script:DcNumber $s
    if ($null -eq $newAc -or $null -eq $newDc -or
        !(Check-Value $s $newAc) -or !(Check-Value $s $newDc)) {
        Alert 'Invalid setting values. Only registered choices or bounded numeric values are accepted.' 'Validation error'
        return
    }
    if ($newAc -eq $s.AC -and $newDc -eq $s.DC) { Alert 'Values have not changed.'; return }
    $question = "Setting: $($s.Name)`r`nPower plan: $($script:PlanId)`r`n" +
        "AC: $($s.AC) -> $newAc`r`nDC: $($s.DC) -> $newDc`r`n`r`n" +
        'An exported .pow backup will be required before making these changes. Apply?'
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        $script:MainForm, $question, 'Confirm power changes',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    try {
        $backup = Make-Backup
        $oldAc = $s.AC
        $oldDc = $s.DC
        $changedAc = $false
        if ($newAc -ne $oldAc) {
            $r = Run-PowerCfg -Arguments @('/setacvalueindex', $script:PlanId, $s.GroupId, $s.Id, "$newAc")
            if (!$r.OK) { throw "AC update failed: $($r.Text)" }
            $changedAc = $true
        }
        if ($newDc -ne $oldDc) {
            $r = Run-PowerCfg -Arguments @('/setdcvalueindex', $script:PlanId, $s.GroupId, $s.Id, "$newDc")
            if (!$r.OK) {
                if ($changedAc) {
                    $undo = Run-PowerCfg -Arguments @('/setacvalueindex', $script:PlanId, $s.GroupId, $s.Id, "$oldAc")
                    if (!$undo.OK) { throw "DC update failed; AC rollback also failed: $($undo.Text). Backup: $backup" }
                }
                throw "DC update failed: $($r.Text). Any successful AC update was rolled back."
            }
        }
        if ($script:PlanId -eq $script:ActivePlanId) {
            $r = Run-PowerCfg -Arguments @('/setactive', $script:PlanId)
            if (!$r.OK) { Alert "Values saved, but reactivating the plan returned an error: $($r.Text)" 'Activation warning' }
        }
        Read-Values
        Refresh-Grid
        Alert "Power setting update completed. Re-read values are displayed.`r`n`r`nBackup: $backup"
    } catch {
        Alert $_.Exception.Message 'Power setting update failed'
        try { Read-Values; Refresh-Grid } catch { }
    }
})

function Get-FilteredDevices {
    $needle = $script:DeviceSearch.Text.Trim()
    return @($script:Devices | Where-Object {
        !$needle -or $_.Name.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
            $_.Class.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
            $_.InstanceId.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    })
}
function Refresh-DeviceTree {
    $script:DeviceTree.BeginUpdate()
    try {
        $script:DeviceTree.Nodes.Clear()
        $filtered = @(Get-FilteredDevices)
        $root = New-Object System.Windows.Forms.TreeNode("Matching devices ($($filtered.Count))")
        $root.Tag = '*'; [void]$script:DeviceTree.Nodes.Add($root)
        foreach ($class in @($filtered | ForEach-Object Class | Sort-Object -Unique)) {
            $count = @($filtered | Where-Object { $_.Class -eq $class }).Count
            $node = New-Object System.Windows.Forms.TreeNode("$class ($count)")
            $node.Tag = $class; [void]$root.Nodes.Add($node)
        }
        $root.Expand(); $script:DeviceTree.SelectedNode = $root
        $script:DeviceTree.TopNode = $root
    } finally { $script:DeviceTree.EndUpdate() }
}
function Refresh-DeviceGrid {
    $script:DeviceGrid.Rows.Clear()
    $tag = if ($script:DeviceTree.SelectedNode) { $script:DeviceTree.SelectedNode.Tag } else { '*' }
    foreach ($d in @(Get-FilteredDevices | Where-Object { $tag -eq '*' -or $_.Class -eq $tag } | Sort-Object Name)) {
        $idx = $script:DeviceGrid.Rows.Add($d.Name, $d.Class, $d.Status)
        $script:DeviceGrid.Rows[$idx].Tag = $d
    }
    if ($script:DeviceGrid.Rows.Count -eq 0) {
        $script:DeviceText.Text = 'No devices match this filter.'
        $readDeviceProperties.Enabled = $false
        $script:DeviceSourceUrl = $null
        $script:DeviceDocsButton.Enabled = $false
    } else {
        $script:DeviceGrid.Rows[0].Selected = $true
        Show-Device $script:DeviceGrid.Rows[0].Tag
    }
    Update-PowerBrowseStatus
}
function Show-Device([object]$Device) {
    if (!$Device) { return }
    $doc = $script:DeviceReference[$Device.Class]
    $script:DeviceSourceUrl = Get-ReferenceUrl $doc
    $script:DeviceDocsButton.Enabled = [bool]$script:DeviceSourceUrl
    $extra = @()
    if ($doc) {
        $extra = @('', '--- Microsoft device-class guidance (not device-specific proof) ---',
            [string]$doc.summary, "Reference: $($doc.url)")
    }
    Set-SectionText $script:DeviceText 'Device details' ((@(
        "Device: $($Device.Name)", "Class: $($Device.Class)", "Status: $($Device.Status)",
        "PnP instance ID: $($Device.InstanceId)", '',
        'Device capabilities depend on hardware, driver and firmware.',
        'See Device Manager > Properties for supported Power Management / Advanced tabs.'
    ) + $extra) -join "`r`n")
    $propertyText = 'Additional driver properties have not been read. Use Read device properties.'
    if ($script:DevicePropertyCache.ContainsKey($Device.InstanceId)) { $propertyText = $script:DevicePropertyCache[$Device.InstanceId] }
    $script:DeviceText.AppendText("`r`n`r`n" + $propertyText)
    $script:DeviceText.Select(0,0); $script:DeviceText.ScrollToCaret()
    Show-DeviceDiagnostics
    $readDeviceProperties.Enabled = $true
}
function Show-DeviceDiagnostics {
    Set-SectionText $script:DeviceDiagnosticsText 'System-wide diagnostics (snapshot)' ((@(
        '--- Supported sleep states ---', $script:SleepInfo,
        '', '--- Devices allowed to wake the PC ---', $script:WakeInfo,
        '', '--- Devices with configurable wake policy ---', $script:ProgrammableWakeInfo,
        '', '--- Current power requests ---', $script:RequestsInfo
    )) -join "`r`n")
}
function Refresh-Devices {
    Invoke-PowerRead 'Devices' {
        Set-PowerCollectionStage 'Reading present devices'
        $devices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                Class = $(if ($_.Class) { [string]$_.Class } else { '(unclassified)' })
                Name = $(if ($_.FriendlyName) { [string]$_.FriendlyName } else { [string]$_.InstanceId })
                Status = [string]$_.Status; InstanceId = [string]$_.InstanceId
            }
        })
        $diagnostics = @{}
        foreach ($query in @(
            @{Name='SleepInfo';Arguments=@('/a')}, @{Name='WakeInfo';Arguments=@('/devicequery','wake_armed')},
            @{Name='ProgrammableWakeInfo';Arguments=@('/devicequery','wake_programmable')},
            @{Name='RequestsInfo';Arguments=@('/requests')})) {
            Set-PowerCollectionStage ('Reading ' + $query.Name)
            $response = Run-PowerCfg -Arguments $query.Arguments
            if (!$response.OK) { throw ($query.Name + ': ' + $response.Text) }
            $diagnostics[$query.Name] = $response.Text
        }
        $script:Devices = $devices
        foreach ($key in $diagnostics.Keys) { Set-Variable -Name $key -Scope Script -Value $diagnostics[$key] }
        $script:DevicePropertyCache = @{}; $script:DeviceLoaded = $true
    } {
        Refresh-DeviceTree
        Show-DeviceDiagnostics
        Update-PowerBrowseStatus
    }
}
function Read-SelectedDeviceProperties {
    if ($script:CollectionBusy -or !$script:DeviceGrid.SelectedRows.Count) { return }
    $device = $script:DeviceGrid.SelectedRows[0].Tag
    Invoke-PowerRead 'Device properties' {
        Set-PowerCollectionStage 'Reading selected device driver properties'
        $property = Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName 'DEVPKEY_Device_PowerData' -ErrorAction Stop
        $cache = $script:DevicePropertyCache.Clone()
        $cache[$device.InstanceId] = 'Driver-exposed DEVPKEY_Device_PowerData:' + "`r`n" + ($property.Data | Out-String).Trim()
        $script:DevicePropertyCache = $cache
    } { Show-Device $device }
}
$script:DeviceTree.Add_AfterSelect({ Refresh-DeviceGrid })
$script:DeviceSearch.Add_TextChanged({ if ($script:DeviceLoaded) { Refresh-DeviceTree } })
$script:DeviceGrid.Add_SelectionChanged({
    if ($script:DeviceGrid.SelectedRows.Count -eq 1) {
        Show-Device $script:DeviceGrid.SelectedRows[0].Tag
    }
})
$refreshDevices.Add_Click({ Refresh-Devices })
$script:Tabs.Add_SelectedIndexChanged({ Update-PowerBrowseStatus })
$readDeviceProperties.Add_Click({ Read-SelectedDeviceProperties })
$openDevices.Add_Click({ Start-Process devmgmt.msc })
$openPowerSettings.Add_Click({ Start-Process 'ms-settings:powersleep' })
$script:DeviceDocsButton.Add_Click({ Open-ReferenceUrl $script:DeviceSourceUrl })

try {
    [void]$script:MainForm.ShowDialog()
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Startup error: $($_.Exception.Message)", 'Power Explorer', 'OK', 'Error'
    ) | Out-Null
    throw
} finally { $script:MainForm.Dispose() }
