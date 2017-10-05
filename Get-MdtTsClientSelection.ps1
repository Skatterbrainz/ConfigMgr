
$dataset = @(
	'Austin	OU=Workstations,OU=Texas,OU=Corp,DC=contoso,DC=com	OU=Users,OU=Texas,OU=Corp,DC=contoso,DC=com	CustomFile_Austin_101.exe',
    'Boston	OU=Workstations,OU=NE,OU=Corp,DC=contoso,DC=com	OU=Users,OU=NE,OU=Corp,DC=contoso,DC=com	CustomFile_NE_103.exe',
	'Mannhatten	OU=Workstations,OU=NYC,OU=Corp,DC=contoso,DC=com	OU=Users,OU=NYC,OU=Corp,DC=contoso,DC=com	CustomFile_NYC_102.exe',
    'Brooklyn	OU=Workstations,OU=NYC,OU=Corp,DC=contoso,DC=com	OU=Users,OU=NYC,OU=Corp,DC=contoso,DC=com	CustomFile_NYC_105.exe',
)

function Get-MdtDataRow {
    param (
        [parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()] $ArraySet,
        [parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()] $KeyValue
    )
    foreach ($row in $ArraySet) {
        $rowset = $row.Split("`t")
        if ($rowset[0] -eq $KeyValue) {
            $result = $rowset
            break
        }
    }
    Write-Output $result
}

function Get-MdtInput {
    param (
        [parameter(Mandatory=$False)]
        [string] $Caption = "Select an Option"
    )
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form 
    $form.Text = "$Caption"
    $form.Size = New-Object System.Drawing.Size(300,200) 
    $form.StartPosition = "CenterScreen"

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(75,120)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(150,120)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = "Cancel"
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $CancelButton
    $form.Controls.Add($CancelButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20) 
    $label.Size = New-Object System.Drawing.Size(280,20) 
    $label.Text = "Please make a selection from the list below:"
    $form.Controls.Add($label) 

    $listBox = New-Object System.Windows.Forms.Listbox 
    $listBox.Location = New-Object System.Drawing.Point(10,40) 
    $listBox.Size = New-Object System.Drawing.Size(260,20) 

    #$listBox.SelectionMode  = "MultiExtended"

    foreach ($set in $dataset) {
        $row = $set.split("`t")
        [void] $listBox.Items.Add($row[0])
    }
    $listBox.Height = 70
    $form.Controls.Add($listBox) 
    $form.Topmost = $True

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $x = $listBox.SelectedItems
        $x
    }
}

$choice = Get-MdtInput -Caption "Select Location"

if ($choice) {
    $data = Get-MdtDataRow -ArraySet $dataset -KeyValue $choice
    $ou1 = $data[1] # machine OU path
    $ou2 = $data[2] # user OU path
    $fn1 = $data[3] # custom installer file
    Write-Host "Laptop OU: $ou1"
    Write-Host "User OU: $ou2"
    Write-Host "Naverisk file: $fn1"
	try {
		$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
		$tsenv.Value("MachineObjectOU") = $ou1
		$tsenv.Value("NaveriskFile") = $fn1
	}
	catch {
		Write-Warning "Script will only assign values while running within a Task Sequence"
	}
}
