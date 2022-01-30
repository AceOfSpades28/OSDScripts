# Script OSD_PasswordChecker.ps1 - Version 1802
# ***** Disclaimer *****
# This file is provided "AS IS" with no warranties, confers no 
# rights, and is not supported by the authors or Microsoft 
# Corporation. Its use is subject to the terms specified in the 
# Terms of Use (http://www.microsoft.com/info/cpyright.mspx).
#

# ----------------------------------------------------------------------------------------------------------------------------------------
# Function Section
# ----------------------------------------------------------------------------------------------------------------------------------------

function ok-button {
    <#
    .SYNOPSIS
    Compares the entered Password with the OSDPassword 
    .DESCRIPTION
    Function to compare the Task Sequence Varibale "OSDPassword" with the entered Password
    #> 

    if($tsenv.Value("OSDPassword") -eq $MaskedTextBox) {
        $tsenv.Value("OSDPasswordChecked")=$True    
    }
}

# ----------------------------------------------------------------------------------------------------------------------------------------
# Worker Section
# ----------------------------------------------------------------------------------------------------------------------------------------
    
# Construct TSEnv object
try {
    $TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction Stop
}
catch [System.Exception] {
    Write-Warning -Message "Unable to construct Microsoft.SMS.TSEnvironment object" ; exit 1
}

#GUI Creation
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 

$objForm = New-Object System.Windows.Forms.Form 
$objForm.Text = "OSD PasswordChecker"
$objForm.Size = New-Object System.Drawing.Size(300,200) 
$objForm.StartPosition = "CenterScreen"
$objForm.KeyPreview = $True

$objForm.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        ok-button;$objForm.Close()
    }
})
$objForm.Add_KeyDown({
    if ($_.KeyCode -eq "Escape") {
        $objForm.Close()
    }
})

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(75,120)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.Add_Click({
    ok-button;$objForm.Close()
})
$objForm.Controls.Add($OKButton)

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(150,120)
$CancelButton.Size = New-Object System.Drawing.Size(75,23)
$CancelButton.Text = "Cancel"
$CancelButton.Add_Click({
    $objForm.Close()
})
$objForm.Controls.Add($CancelButton)

$objLabel = New-Object System.Windows.Forms.Label
$objLabel.Location = New-Object System.Drawing.Size(10,20) 
$objLabel.Size = New-Object System.Drawing.Size(280,20) 
$objLabel.Text = "Please enter the information in the space below:"
$objForm.Controls.Add($objLabel) 

$MaskedTextBox = New-Object System.Windows.Forms.MaskedTextBox
$MaskedTextBox.PasswordChar = '*'
$MaskedTextBox.Location = New-Object System.Drawing.Size(10,40) 
$MaskedTextBox.Size = New-Object System.Drawing.Size(260,20) 
$objForm.Controls.Add($MaskedTextBox) 
$objForm.Topmost = $True
$objForm.Add_Shown({$objForm.Activate()})

[void] $objForm.ShowDialog()