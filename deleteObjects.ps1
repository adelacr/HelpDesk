<#
.Synopsis
   A graphical user interface (GUI) to search and delete objects, computers, from the MHC environment. 
.DESCRIPTION
   A graphical user interface (GUI) that can remain open to search and delete objects, computers, from the MHC environment. The script was designed to be used by HelpDesk and any MHC employee required to remove computer objects from the environment.
.NOTES
  Version:        1.0
  Author:         Anthony De La Cruz
  Creation Date:  12/07/2021
  Purpose/Change: Delete computer objects from MHC environment.   
#>


function connect-cloud 
{
    $intuneId = Connect-MSGraph –ErrorAction Stop
    $aadId = Connect-AzureAD –AccountId $intuneId.UPN –ErrorAction Stop
}

function get-adInfo 
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true)]
        $computerName
    )
    
    $activeDirectory = Get-ADComputer $computerName -ErrorAction SilentlyContinue

    $Global:AD_Info = $activeDirectory
 
    $presentAD = if ( $activeDirectory ){ 
        "$computerName is present in Active Directory"  
    }
    else{
        "$computerName not found in Active Directory"
    }
    $scriptOutputAD = $presentAD | Out-String -Stream

    return $scriptOutputAD
}

function get-mecmInfo
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        $computerName
    )
    # Import the ConfigurationManager.psd1 module.
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"

    # Change the working location. Required to access data from SCCM  
    Set-Location MH1:

    $sccm = Get-CMDevice -Name $computerName -Fast
    $Global:AADDeviceID = $sccm
    $presentSCCM = if ( $sccm -ne $null ){
        "$computerName is present in Microsoft Endpoint Configuration Manager"
    }
    else {
        "$computerName not found in Microsoft Endpoint Configuration Manager"
    }
    $scriptOutputMecm = $presentSCCM | Out-String -Stream

    return $scriptOutputMecm
}

function get-azureInfo
{
        [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true)]
        $computerName
    )
    $azureAD = Get-AzureADDevice -SearchString $computerName | ? { $_.DeviceId -eq $Global:AADDeviceID.AADDeviceID -or $_.DeviceId -eq $Global:AD_Info.ObjectGUID }

    $Global:azureInfo = $azureAD

    $presentAzure = if ( $azureAD -ne $null ){
        "$computerName is present in Azure"
    }
    else {
        "$computerName not found in Azure"
    }
    $scriptOutputAzure = $presentAzure | Out-String -Stream

    return $scriptOutputAzure
}

function get-intuneInfo
{
        [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true)]
        $computerName
    )
    $Global:intuneDevices = Get-IntuneManagedDevice –Filter "deviceName eq '$ComputerName'" | ? { $_.azureADDeviceId -eq $Global:AADDeviceID.AADDeviceID -or $_.azureADDeviceId -eq $Global:AD_Info.ObjectGUID   } 

    $presentIntune = if ( $intuneDevices -ne $null ){
        "$computerName is present in Intune"
    }
    else {
        "$computerName not found in Intune"
    }
    $scriptOutputIntune = $presentIntune | Out-String -Stream

    return $scriptOutputIntune
}

connect-cloud

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$Form = New-Object system.Windows.Forms.Form
$Form.ClientSize = '800,500'
$Form.text = "Remove computer Object from MHC"
$Form.TopMost = $false

$LabelQuestion = New-Object System.Windows.Forms.Label
$LabelQuestion.Location = New-Object System.Drawing.Size(18,20) 
$LabelQuestion.Size = New-Object System.Drawing.Size(350,20) 
$LabelQuestion.Text = "Enter Hostname"
$Form.Controls.Add($LabelQuestion)

$Button1 = New-Object system.Windows.Forms.Button
$Button1.text = "Search"
$Button1.width = 110
$Button1.height = 40
$Button1.location = New-Object System.Drawing.Point(18,400)
$Button1.Font = ('Microsoft Sans Serif,10')

$Button2 = New-Object system.Windows.Forms.Button
$Button2.text = "Delete Object"
$Button2.width = 110
$Button2.height = 40
$Button2.location = New-Object System.Drawing.Point(130,400)
$Button2.Font = 'Microsoft Sans Serif,10'

$Button3 = New-Object system.Windows.Forms.Button
$Button3.text = "Validate"
$Button3.width = 110
$Button3.height = 40
$Button3.location = New-Object System.Drawing.Point(242,400)
$Button3.Font = 'Microsoft Sans Serif,10'

$Button4 = New-Object system.Windows.Forms.Button
$Button4.text = "Exit"
$Button4.width = 110
$Button4.height = 40
$Button4.location = New-Object System.Drawing.Point(660,400)
$Button4.Font = 'Microsoft Sans Serif,10'
$Button4.Add_Click({$Form.Close()})#On click do function

$TextBox1 = New-Object system.Windows.Forms.TextBox
# $TextBox1.multiline = $true
$TextBox1.width = 200
$TextBox1.height = 50
$TextBox1.Text = ""
$TextBox1.location = New-Object System.Drawing.Point(20,50)
$TextBox1.Font = 'Microsoft Sans Serif,14'

$outputBox = New-Object System.Windows.Forms.TextBox 
$outputBox.Location = New-Object System.Drawing.Size(18,90) 
$outputBox.Size = New-Object System.Drawing.Size(750,300) 
$outputBox.MultiLine = $True 
$outputBox.ScrollBars = "Vertical"
$outputBox.Font = 'Microsoft Sans Serif,14'
$Form.Controls.Add($outputBox)

$Form.controls.AddRange(@($Button1,$Button2,$Button3,$Button4,$TextBox1))

$Button1.Add_Click({
    if ( $TextBox1.Text -eq "" ){
        $outputBox.Text = "Enter hostname to search for the device"
    }
    else{
    $scriptOutputAD = get-adInfo -computerName $TextBox1.Text
    $scriptOutputMecm = get-mecmInfo -computerName $TextBox1.Text
    $scriptOutputAzure = get-azureInfo -computerName $TextBox1.Text
    $scriptOutputIntune = get-intuneInfo -computerName $TextBox1.Text
    $outputBox.Text = ("$scriptOutputAD `r`n$scriptOutputMecm `r`n$scriptOutputAzure `r`n$scriptOutputIntune")
    }
})

$Button2.Add_Click({
    $outputBox.Text = ("The device " + $TextBox1.Text.ToUpper() + " will be deleted MHC. `r`nClick Validate to continue")
})

$Button3.Add_CLick({

    function remove-object
    {
        # Delete from System Center
        If ( $Global:AADDeviceID.Name ){
            $comp = $Global:AADDeviceID.Name
            Remove-CMDevice -Name $comp -Force 
        }

        # Delete from Azure
        if ( $Global:azureInfo.ObjectId ){
            Remove-AzureADDevice –ObjectId $Global:azureInfo.ObjectId
        }

        # Delete from Active Directory
        if ( $Global:AD_Info.Name ){
            $cred = Get-Credential -Credential ($env:USERNAME + "admin")
            Get-ADComputer -Identity $Global:AD_Info.Name | Remove-ADObject -Recursive -Credential $cred -Confirm:$false
        }

        # Delete from Intune
        if ( $Global:intuneDevices.Id ){
            Remove-IntuneManagedDevice –managedDeviceId $Global:intuneDevices.Id
        }
    }
    remove-object

    $outputBox.Text = "Device has been cleared. Run search again to verify."
})

[void]$Form.ShowDialog()
# SIG # Begin signature block
# MIIFlAYJKoZIhvcNAQcCoIIFhTCCBYECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUkt5T2io3XrC/ZzxyDVNwUhnY
# CL6gggMiMIIDHjCCAgagAwIBAgIQd2PzONC9iZhBdMNDLNll3jANBgkqhkiG9w0B
# AQsFADAnMSUwIwYDVQQDDBxQb3dlclNoZWxsIENvZGUgU2lnbmluZyBDZXJ0MB4X
# DTIxMTEzMDIyNTAzNloXDTIyMTEzMDIzMTAzNlowJzElMCMGA1UEAwwcUG93ZXJT
# aGVsbCBDb2RlIFNpZ25pbmcgQ2VydDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBALVHPD0HollH1WUdaeQFO3nge2PYEIKvdDIhdAqofBaE0sI34jAC7Y4v
# is9WvNOIdTMtxP5LbsVjiJ+OchX+WPaZPQsfdAdurYFC1J/55LJ0gmo3GIUewEC3
# 6RCy3QKNHggGgdBauLa6FL+IswgpJVwFNgyplbO59DnNjwQw1lkzQZ5EdXuvLJdL
# c6Qrlb/tmqAUVuv7IA5io2Rvqt2Y3b1cC5ypqpL8fw3tII3IRsouZugKIT6uSRsb
# 37G/poiXFoMwHgJvcmbCNm+5MsPtfLjGGhAaCiwfhRN7fH/vFyqbEK3CxcgHdqst
# bxRE+/wtUiWD7CiK5jPuZbApAuhIt6UCAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeA
# MBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBRVuZ6vwbF8ENHlV5flJ5EZ
# YdcZODANBgkqhkiG9w0BAQsFAAOCAQEApUdkscY16XilkOPvhrFEZCYyPFaM4qYm
# 8f6ykp1vmJPW+krl9blgUbasYaSVnJjQCNpyP9cEcArGiQ827azQqbBhg5FWOrum
# E0aXWEWfPBOVkoJBzah2wUlBZAUtnA6/hdju6GG025GzpzBbLVUc69PGHIMbhtBa
# Q5ApH826iLusRCl4W+kx78LQgDC5zHjRKPM4XkE9lPRE/ht0N808kvQyUMYzkiCr
# uM8WZ8jH7ocsW5+eFyZDX6scAgaD4o3pzVdScwRmJIHvYQUtKioAsCPREqVOdadz
# h098IpEYA4yx34DG8cwysR2FtVXCoXbrYy6zHxoQ6OLVuA+qXDq/FjGCAdwwggHY
# AgEBMDswJzElMCMGA1UEAwwcUG93ZXJTaGVsbCBDb2RlIFNpZ25pbmcgQ2VydAIQ
# d2PzONC9iZhBdMNDLNll3jAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUhSEdtK+IdraCBfzAYRR0
# zb948S0wDQYJKoZIhvcNAQEBBQAEggEAT0x+poFk41yexc7gDD0C0SHu1vTT41mT
# SZhqLMiFFUn4iV5EJJhVYwApMUovcVwgnHXMBHq3xST/htZhK0/Aa0+So4Kf3F+R
# lmBA/i6Aha6JwO18WYqfvk7frR1FLX7/uPVVyxQsL8y+NWtgF5JGuiof3hyhj+sm
# RXFVdBZp3qpcLeT37HUVHjIzHWVPVq5LlzjAKUsNK9jc8FNsy4P3NQWvi01i8Ilz
# xLgaGsIuRKUAhmUdRzG/paolTswP0zUX6X3s3dAgejUrICrf01p63sAy1Sgw29Kz
# zoXAxDAv4ctNzpHi693V7S9Kep/4yzalQVHNe9YeaMnvoD++8dfzdw==
# SIG # End signature block
