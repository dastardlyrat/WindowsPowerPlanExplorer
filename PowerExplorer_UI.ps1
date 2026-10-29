# UI-only section builders. No inventory or configuration commands run here.
function New-LockedRichBox([string]$Name, [bool]$Wrap = $true) {
    $box = New-Object System.Windows.Forms.RichTextBox
    $box.Name = $Name; $box.Dock = 'Fill'
    $box.ReadOnly = $true; $box.Enabled = $true; $box.DetectUrls = $false
    $box.WordWrap = $Wrap; $box.HideSelection = $false
    $box.AcceptsTab = $false; $box.ShortcutsEnabled = $true
    $box.ScrollBars = $(if ($Wrap) { 'Vertical' } else { 'Both' })
    $box.BackColor = [System.Drawing.SystemColors]::Window
    $box.BorderStyle = 'FixedSingle'
    return $box
}
function Set-SectionText($Box, [string]$Heading, [string]$Body) {
    $Box.Clear()
    $font = New-Object System.Drawing.Font($Box.Font, [System.Drawing.FontStyle]::Bold)
    try {
        $Box.SelectionFont = $font
        $Box.AppendText($Heading + [Environment]::NewLine)
        $Box.SelectionFont = $Box.Font
        $Box.AppendText($Body)
        $Box.Select(0,0); $Box.ScrollToCaret()
    } finally { $font.Dispose() }
}
function New-TextSection([string]$Name, [string]$Title, [bool]$Wrap = $true) {
    $page = New-Object System.Windows.Forms.TabPage
    $page.Name = $Name; $page.Text = $Title
    $page.Padding = New-Object System.Windows.Forms.Padding(3)
    $box = New-LockedRichBox ($Name + 'Text') $Wrap
    $page.Controls.Add($box); $page.Tag = $box
    return $page
}

function Initialize-SectionToolbar($Page, $Toolbar, $Browse, $Actions) {
    # Measure actual flow rows after wrapping. AutoSize tables otherwise reserve
    # rows measured at the flow panel's tiny initial width, starving split panes.
    $Page.RowStyles[0].SizeType = 'Absolute'; $Page.RowStyles[0].Height = 88
    $Toolbar.AutoSize = $false; $Toolbar.Dock = 'Fill'
    $Toolbar.RowStyles[0].SizeType = 'Absolute'; $Toolbar.RowStyles[0].Height = 34
    $Toolbar.RowStyles[1].SizeType = 'Percent'; $Toolbar.RowStyles[1].Height = 100
    $Browse.AutoSize = $false; $Browse.Dock = 'Fill'
    $Actions.AutoSize = $false; $Actions.Dock = 'Fill'
    $Actions.Tag = @{ Page = $Page; Toolbar = $Toolbar }
    $Actions.Add_Layout({
        param($sender, $eventArgs)
        $bottom = 0
        foreach ($child in $sender.Controls) {
            $bottom = [Math]::Max($bottom, $child.Bottom + $child.Margin.Bottom)
        }
        $target = 34 + [Math]::Max(35, $bottom) + $sender.Margin.Vertical +
            $sender.Tag.Toolbar.Padding.Vertical + $sender.Tag.Toolbar.Margin.Vertical + 6
        if ([Math]::Abs($sender.Tag.Page.RowStyles[0].Height - $target) -gt 1) {
            $sender.Tag.Page.RowStyles[0].Height = $target
        }
    })
}

function New-Button([string]$Text, [int]$Width) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text; $b.Width = $Width; $b.Height = 29
    return $b
}
function New-Grid {
    $g = New-Object System.Windows.Forms.DataGridView
    $g.Dock = 'Fill'; $g.ReadOnly = $true; $g.AllowUserToAddRows = $false
    $g.AllowUserToDeleteRows = $false; $g.AllowUserToResizeRows = $false
    $g.SelectionMode = 'FullRowSelect'; $g.MultiSelect = $false
    $g.RowHeadersVisible = $false; $g.AutoSizeColumnsMode = 'Fill'
    $g.BackgroundColor = [System.Drawing.Color]::White
    return $g
}
function Add-GridColumn($Grid, [string]$Name, [string]$Header, [int]$Weight) {
    $column = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $column.Name = $Name; $column.HeaderText = $Header
    $column.FillWeight = $Weight; $column.SortMode = 'NotSortable'
    [void]$Grid.Columns.Add($column)
}
function New-Label([string]$Text, [int]$X, [int]$Y, [int]$Width = 100) {
    $lab = New-Object System.Windows.Forms.Label
    $lab.Text = $Text
    $lab.SetBounds($X, $Y, $Width, 23)
    return $lab
}

# Layout
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:MainForm = New-Object System.Windows.Forms.Form
$script:MainForm.Text = 'Power Explorer 1.2 - Windows 11'
$script:MainForm.Size = New-Object System.Drawing.Size(1230, 790)
$script:MainForm.MinimumSize = New-Object System.Drawing.Size(990, 680)
$script:MainForm.StartPosition = 'CenterScreen'
$script:MainForm.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$script:MainForm.AutoScaleMode = 'Font'
$script:MainForm.Add_FormClosing({ param($sender, $eventArgs) if ($script:CollectionBusy) { $eventArgs.Cancel = $true } })

$script:Tabs = New-Object System.Windows.Forms.TabControl
$script:Tabs.Dock = 'Fill'
$tabPlans = New-Object System.Windows.Forms.TabPage
$tabPlans.Text = 'Power plans'
$tabDevices = New-Object System.Windows.Forms.TabPage
$tabDevices.Text = 'Devices and wake'
# Explicit table layouts avoid WinForms Dock=Fill/Top z-order overlap on both tabs.
$planPage = New-Object System.Windows.Forms.TableLayoutPanel
$planPage.Dock = 'Fill'; $planPage.RowCount = 2; $planPage.ColumnCount = 1
$planPage.Margin = New-Object System.Windows.Forms.Padding(0)
$planPage.Padding = New-Object System.Windows.Forms.Padding(0)
[void]$planPage.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
[void]$planPage.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
[void]$planPage.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
$tabPlans.Controls.Add($planPage)
$devicePage = New-Object System.Windows.Forms.TableLayoutPanel
$devicePage.Dock = 'Fill'; $devicePage.RowCount = 2; $devicePage.ColumnCount = 1
$devicePage.Margin = New-Object System.Windows.Forms.Padding(0)
$devicePage.Padding = New-Object System.Windows.Forms.Padding(0)
[void]$devicePage.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
[void]$devicePage.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
[void]$devicePage.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
$tabDevices.Controls.Add($devicePage)
[void]$script:Tabs.TabPages.Add($tabPlans)
[void]$script:Tabs.TabPages.Add($tabDevices)
$script:MainForm.Controls.Add($script:Tabs)

$script:StatusStrip = New-Object System.Windows.Forms.StatusStrip
$script:StatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$script:StatusLabel.Text = 'Read-only until editing is enabled.'
$script:StatusLabel.Spring = $true
$script:StatusLabel.TextAlign = 'MiddleLeft'
$script:EditModeLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$script:EditModeLabel.Text = 'Browsing ' + [char]0x2014 + ' editing disabled'
$script:EditModeLabel.BorderSides = 'Left'
[void]$script:StatusStrip.Items.Add($script:StatusLabel)
[void]$script:StatusStrip.Items.Add($script:EditModeLabel)
$script:MainForm.Controls.Add($script:StatusStrip)

$planToolbar = New-Object System.Windows.Forms.TableLayoutPanel
$planToolbar.Dock = 'Top'; $planToolbar.AutoSize = $true
$planToolbar.AutoSizeMode = 'GrowAndShrink'
$planToolbar.ColumnCount = 1; $planToolbar.RowCount = 2
$planToolbar.Margin = New-Object System.Windows.Forms.Padding(0)
$planToolbar.Padding = New-Object System.Windows.Forms.Padding(6)
[void]$planToolbar.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
foreach ($row in 0..1) {
    [void]$planToolbar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
}
$planPage.Controls.Add($planToolbar, 0, 0)

$browseRow = New-Object System.Windows.Forms.TableLayoutPanel
$browseRow.Dock = 'Top'; $browseRow.AutoSize = $true
$browseRow.AutoSizeMode = 'GrowAndShrink'
$browseRow.ColumnCount = 5; $browseRow.RowCount = 1
$browseRow.Margin = New-Object System.Windows.Forms.Padding(0)
foreach ($width in @(76, 0, 56, 0, 124)) {
    $style = New-Object System.Windows.Forms.ColumnStyle('Absolute', $width)
    [void]$browseRow.ColumnStyles.Add($style)
}
$browseRow.ColumnStyles[1].SizeType = 'Percent'; $browseRow.ColumnStyles[1].Width = 50
$browseRow.ColumnStyles[3].SizeType = 'Percent'; $browseRow.ColumnStyles[3].Width = 50
[void]$browseRow.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
$planToolbar.Controls.Add($browseRow, 0, 0)
$planLabel = New-Label 'Power plan' 0 0 76
$planLabel.Dock = 'Fill'; $planLabel.TextAlign = 'MiddleLeft'
$browseRow.Controls.Add($planLabel, 0, 0)
$script:PlansCombo = New-Object System.Windows.Forms.ComboBox
$script:PlansCombo.DropDownStyle = 'DropDownList'; $script:PlansCombo.Dock = 'Fill'
$script:PlansCombo.DisplayMember = 'Label'
$browseRow.Controls.Add($script:PlansCombo, 1, 0)
$searchLabel = New-Label 'Search' 0 0 50
$searchLabel.Dock = 'Fill'; $searchLabel.TextAlign = 'MiddleLeft'
$browseRow.Controls.Add($searchLabel, 2, 0)
$script:Search = New-Object System.Windows.Forms.TextBox
$script:Search.Dock = 'Fill'
$browseRow.Controls.Add($script:Search, 3, 0)
$script:ShowHidden = New-Object System.Windows.Forms.CheckBox
$script:ShowHidden.Text = 'Include hidden'; $script:ShowHidden.Checked = $true
$script:ShowHidden.Dock = 'Fill'
$browseRow.Controls.Add($script:ShowHidden, 4, 0)

$actionRow = New-Object System.Windows.Forms.FlowLayoutPanel
$actionRow.Dock = 'Top'; $actionRow.AutoSize = $true
$actionRow.AutoSizeMode = 'GrowAndShrink'; $actionRow.WrapContents = $true
$actionRow.Margin = New-Object System.Windows.Forms.Padding(0, 3, 0, 0)
$planToolbar.Controls.Add($actionRow, 0, 1)
$script:AllowEdit = New-Object System.Windows.Forms.CheckBox
$script:AllowEdit.Text = 'Enable editing'; $script:AllowEdit.AutoSize = $true
$script:AllowEdit.Margin = New-Object System.Windows.Forms.Padding(3, 8, 18, 3)
$actionRow.Controls.Add($script:AllowEdit)
$refreshPlan = New-Button 'Collect / refresh plans' 155
$backupPlan = New-Button 'Back up plan' 95
$exportCatalog = New-Button 'Export catalog' 105
$openAdvanced = New-Button 'Advanced options' 112
$actionRow.Controls.Add($refreshPlan)
$actionRow.Controls.Add($backupPlan)
$actionRow.Controls.Add($exportCatalog)
$actionRow.Controls.Add($openAdvanced)

$planSplit = New-Object System.Windows.Forms.SplitContainer
$planSplit.Size = New-Object System.Drawing.Size(1150, 610)
$planSplit.Dock = 'Fill'; $planSplit.SplitterDistance = 250
$planSplit.Panel1MinSize = 185; $planSplit.Panel2MinSize = 450
$planPage.Controls.Add($planSplit, 0, 1)
$script:Tree = New-Object System.Windows.Forms.TreeView
$script:Tree.Dock = 'Fill'; $script:Tree.HideSelection = $false
$planNav = New-Object System.Windows.Forms.TableLayoutPanel
$planNav.Dock = 'Fill'; $planNav.RowCount = 2; $planNav.ColumnCount = 1
$planNav.Padding = New-Object System.Windows.Forms.Padding(5, 7, 4, 5)
[void]$planNav.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 25)))
[void]$planNav.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
$planNav.Controls.Add((New-Label 'POWER SETTING GROUPS' 0 0 245), 0, 0)
$planNav.Controls.Add($script:Tree, 0, 1)
$planSplit.Panel1.Controls.Add($planNav)

$rightSplit = New-Object System.Windows.Forms.SplitContainer
$rightSplit.Size = New-Object System.Drawing.Size(850, 610)
$rightSplit.Dock = 'Fill'; $rightSplit.Orientation = 'Horizontal'
$rightSplit.SplitterDistance = 280
$rightSplit.Panel1MinSize = 110; $rightSplit.Panel2MinSize = 280
$planSplit.Panel2.Controls.Add($rightSplit)
$script:Grid = New-Grid
Add-GridColumn $script:Grid 'name' 'Setting' 46
Add-GridColumn $script:Grid 'ac' 'Plugged in (AC)' 25
Add-GridColumn $script:Grid 'dc' 'Battery (DC)' 25
Add-GridColumn $script:Grid 'hidden' 'Visibility' 13
$rightSplit.Panel1.Controls.Add($script:Grid)

$details = New-Object System.Windows.Forms.TableLayoutPanel
$details.Dock = 'Fill'; $rightSplit.Panel2.Controls.Add($details)
$details.ColumnCount = 1; $details.RowCount = 5
$details.Padding = New-Object System.Windows.Forms.Padding(9, 6, 9, 6)
[void]$details.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
[void]$details.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
[void]$details.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
foreach ($row in 2..4) {
    [void]$details.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
}
$script:DetailTitle = New-Label 'Select a setting' 0 0 100
$script:DetailTitle.Dock = 'Fill'; $script:DetailTitle.AutoEllipsis = $true
$script:DetailTitle.Margin = New-Object System.Windows.Forms.Padding(3, 0, 3, 4)
$script:DetailTitle.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$details.Controls.Add($script:DetailTitle, 0, 0)
$settingTextSections = New-Object System.Windows.Forms.TabControl
$settingTextSections.Name = 'SettingTextSections'; $settingTextSections.Dock = 'Fill'
$descriptionSection = New-TextSection 'SettingDescription' 'Description'
$evidenceSection = New-TextSection 'SettingEvidence' 'Evidence and reference'
$script:DetailText = $descriptionSection.Tag
$script:EvidenceText = $evidenceSection.Tag
[void]$settingTextSections.TabPages.Add($descriptionSection)
[void]$settingTextSections.TabPages.Add($evidenceSection)
$details.Controls.Add($settingTextSections, 0, 1)

$editorRow = New-Object System.Windows.Forms.TableLayoutPanel
$editorRow.Dock = 'Top'; $editorRow.AutoSize = $true
$editorRow.ColumnCount = 2; $editorRow.RowCount = 2
$editorRow.Margin = New-Object System.Windows.Forms.Padding(0, 3, 0, 0)
foreach ($column in 0..1) {
    [void]$editorRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 50)))
}
[void]$editorRow.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
[void]$editorRow.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
$acLabel = New-Label 'Plugged in (AC)' 0 0 130
$dcLabel = New-Label 'Battery (DC)' 0 0 130
$editorRow.Controls.Add($acLabel, 0, 0)
$editorRow.Controls.Add($dcLabel, 1, 0)
$acHost = New-Object System.Windows.Forms.Panel
$dcHost = New-Object System.Windows.Forms.Panel
foreach ($hostPanel in @($acHost, $dcHost)) {
    $hostPanel.Dock = 'Fill'; $hostPanel.Height = 27
}
$editorRow.Controls.Add($acHost, 0, 1)
$editorRow.Controls.Add($dcHost, 1, 1)
$details.Controls.Add($editorRow, 0, 2)
$script:AcCombo = New-Object System.Windows.Forms.ComboBox
$script:AcCombo.DropDownStyle = 'DropDownList'
$script:AcNumber = New-Object System.Windows.Forms.NumericUpDown
$script:AcNumber.Minimum = 0; $script:AcNumber.Maximum = 4294967295
$script:DcCombo = New-Object System.Windows.Forms.ComboBox
$script:DcCombo.DropDownStyle = 'DropDownList'
$script:DcNumber = New-Object System.Windows.Forms.NumericUpDown
$script:DcNumber.Minimum = 0; $script:DcNumber.Maximum = 4294967295
foreach ($control in @($script:AcCombo, $script:DcCombo, $script:AcNumber, $script:DcNumber)) {
    $control.Dock = 'Top'; $control.Visible = $false; $control.Enabled = $false
}
$acHost.Controls.Add($script:AcCombo); $acHost.Controls.Add($script:AcNumber)
$dcHost.Controls.Add($script:DcCombo); $dcHost.Controls.Add($script:DcNumber)
$detailActions = New-Object System.Windows.Forms.FlowLayoutPanel
$detailActions.Dock = 'Top'; $detailActions.AutoSize = $true
$detailActions.WrapContents = $true; $detailActions.Margin = New-Object System.Windows.Forms.Padding(0)
$details.Controls.Add($detailActions, 0, 3)
$script:SaveButton = New-Button 'Apply AC + DC' 133
$script:SaveButton.Enabled = $false
$detailActions.Controls.Add($script:SaveButton)
$script:DocsButton = New-Button 'Microsoft reference' 147
$script:DocsButton.Enabled = $false
$detailActions.Controls.Add($script:DocsButton)
$script:EditInfo = New-Object System.Windows.Forms.Label
$script:EditInfo.Text = 'Edit is off; choices and bounds come from the installed power-setting definitions.'
$script:EditInfo.Dock = 'Fill'; $script:EditInfo.AutoSize = $true
$script:EditInfo.Margin = New-Object System.Windows.Forms.Padding(3, 3, 3, 0)
$details.Controls.Add($script:EditInfo, 0, 4)
# Constrain wrapping to the actual cell width, including when a splitter moves.
$details.Add_SizeChanged({
    $script:EditInfo.MaximumSize = New-Object System.Drawing.Size(
        ([Math]::Max(1, $details.ClientSize.Width - $details.Padding.Horizontal - 6)), 0)
})

function Update-EditingIndicator {
    if ($script:AllowEdit.Checked) {
        $script:EditModeLabel.Text = 'Editing enabled ' + [char]0x2014 + ' validation still required'
    } else {
        $script:EditModeLabel.Text = 'Browsing ' + [char]0x2014 + ' editing disabled'
    }
}

# Device inventory page
$deviceToolbar = New-Object System.Windows.Forms.TableLayoutPanel
$deviceToolbar.Name = 'DeviceBrowseAndActions'; $deviceToolbar.Dock = 'Top'
$deviceToolbar.AutoSize = $true; $deviceToolbar.AutoSizeMode = 'GrowAndShrink'
$deviceToolbar.ColumnCount = 1; $deviceToolbar.RowCount = 2
[void]$deviceToolbar.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
foreach ($row in 0..1) { [void]$deviceToolbar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))) }
$devicePage.Controls.Add($deviceToolbar, 0, 0)
$deviceBrowse = New-Object System.Windows.Forms.TableLayoutPanel
$deviceBrowse.Name = 'DeviceFilterSection'; $deviceBrowse.Dock = 'Top'; $deviceBrowse.AutoSize = $true
$deviceBrowse.ColumnCount = 2; $deviceBrowse.RowCount = 1
[void]$deviceBrowse.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 120)))
[void]$deviceBrowse.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
$deviceBrowse.Controls.Add((New-Label 'Search devices' 0 0 115), 0, 0)
$script:DeviceSearch = New-Object System.Windows.Forms.TextBox
$script:DeviceSearch.Dock = 'Fill'; $deviceBrowse.Controls.Add($script:DeviceSearch, 1, 0)
$deviceToolbar.Controls.Add($deviceBrowse, 0, 0)
$deviceActions = New-Object System.Windows.Forms.FlowLayoutPanel
$deviceActions.Name = 'DeviceActionSection'; $deviceActions.Dock = 'Top'
$deviceActions.AutoSize = $true; $deviceActions.WrapContents = $true
$deviceToolbar.Controls.Add($deviceActions, 0, 1)
$refreshDevices = New-Button 'Collect / refresh devices' 170
$readDeviceProperties = New-Button 'Read device properties' 155
$readDeviceProperties.Enabled = $false
$openDevices = New-Button 'Device Manager' 120
$openPowerSettings = New-Button 'Windows power settings' 167
$script:DeviceDocsButton = New-Button 'Device reference' 119
$script:DeviceDocsButton.Enabled = $false
foreach ($button in @($refreshDevices,$readDeviceProperties,$openDevices,$openPowerSettings,$script:DeviceDocsButton)) {
    $deviceActions.Controls.Add($button)
}
$deviceSplit = New-Object System.Windows.Forms.SplitContainer
$deviceSplit.Size = New-Object System.Drawing.Size(1150, 610)
$deviceSplit.Dock = 'Fill'; $deviceSplit.SplitterDistance = 220
$devicePage.Controls.Add($deviceSplit, 0, 1)
$script:DeviceTree = New-Object System.Windows.Forms.TreeView
$script:DeviceTree.Dock = 'Fill'; $script:DeviceTree.HideSelection = $false
$deviceNav = New-Object System.Windows.Forms.TableLayoutPanel
$deviceNav.Dock = 'Fill'; $deviceNav.RowCount = 2; $deviceNav.ColumnCount = 1
$deviceNav.Padding = New-Object System.Windows.Forms.Padding(5, 7, 4, 5)
[void]$deviceNav.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 25)))
[void]$deviceNav.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
$deviceNav.Controls.Add((New-Label 'DEVICE CLASSES' 0 0 215), 0, 0)
$deviceNav.Controls.Add($script:DeviceTree, 0, 1)
$deviceSplit.Panel1.Controls.Add($deviceNav)
$deviceRight = New-Object System.Windows.Forms.SplitContainer
$deviceRight.Size = New-Object System.Drawing.Size(870, 610)
$deviceRight.Orientation = 'Horizontal'; $deviceRight.Dock = 'Fill'
$deviceRight.SplitterDistance = 270
$deviceRight.Panel1MinSize = 120; $deviceRight.Panel2MinSize = 170
$deviceSplit.Panel2.Controls.Add($deviceRight)
$script:DeviceGrid = New-Grid
Add-GridColumn $script:DeviceGrid 'devname' 'Device' 57
Add-GridColumn $script:DeviceGrid 'devclass' 'Class' 23
Add-GridColumn $script:DeviceGrid 'devstatus' 'Status' 20
$deviceRight.Panel1.Controls.Add($script:DeviceGrid)
$deviceSections = New-Object System.Windows.Forms.TabControl
$deviceSections.Name = 'DeviceTextSections'; $deviceSections.Dock = 'Fill'
$deviceDescriptionSection = New-TextSection 'DeviceDescription' 'Device details'
$deviceDiagnosticsSection = New-TextSection 'DeviceDiagnostics' 'System diagnostics' $false
$script:DeviceText = $deviceDescriptionSection.Tag
$script:DeviceDiagnosticsText = $deviceDiagnosticsSection.Tag
$script:DeviceDiagnosticsText.Font = New-Object System.Drawing.Font('Consolas', 9)
[void]$deviceSections.TabPages.Add($deviceDescriptionSection)
[void]$deviceSections.TabPages.Add($deviceDiagnosticsSection)
$deviceRight.Panel2.Controls.Add($deviceSections)

# Named sections are independently replaceable; only this file owns composition.
Initialize-SectionToolbar $planPage $planToolbar $browseRow $actionRow
Initialize-SectionToolbar $devicePage $deviceToolbar $deviceBrowse $deviceActions
$planToolbar.Name = 'PlanToolbarSection'; $browseRow.Name = 'PlanFilterSection'
$actionRow.Name = 'PlanActionSection'; $planNav.Name = 'PlanNavigationSection'
$script:Grid.Name = 'PlanResultsSection'; $details.Name = 'SelectedSettingSection'
$editorRow.Name = 'PlanValueSection'; $detailActions.Name = 'PlanEditActionSection'
$deviceNav.Name = 'DeviceNavigationSection'; $script:DeviceGrid.Name = 'DeviceResultsSection'
$windowFrame = New-Object System.Windows.Forms.TableLayoutPanel
$windowFrame.Name = 'ApplicationFrame'; $windowFrame.Dock = 'Fill'
$windowFrame.ColumnCount = 1; $windowFrame.RowCount = 3
[void]$windowFrame.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
[void]$windowFrame.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
[void]$windowFrame.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 68)))
[void]$windowFrame.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 24)))
$script:MainForm.Controls.Clear()
$script:MainForm.Controls.Add($windowFrame)
$windowFrame.Controls.Add($script:Tabs, 0, 0)
$script:CollectionText = New-LockedRichBox 'CollectionStatusSection'
$windowFrame.Controls.Add($script:CollectionText, 0, 1)
$windowFrame.Controls.Add($script:StatusStrip, 0, 2)
Set-SectionText $script:CollectionText 'Collection: not started' 'Use Collect / refresh plans or Collect / refresh devices. Opening a tab does not collect inventory.'
$script:DetailText.Text = 'Collect plans, then select a setting.'
$script:DeviceText.Text = 'Collect devices, then select a device. Additional properties require Read device properties.'
$script:DeviceDiagnosticsText.Text = 'System diagnostics have not been collected.'
$script:StatusLabel.Text = 'No inventory collected'
$backupPlan.Enabled = $false; $exportCatalog.Enabled = $false; $script:AllowEdit.Enabled = $false

