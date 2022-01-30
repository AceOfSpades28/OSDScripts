$latest = (Get-HPBiosUpdates -latest).ver
$current = Get-HPBIOSVersion
If ($current -ne $latest) {
    Get-HPBIOSUpdates -flash -yes -Quiet -bitlocker suspend
}