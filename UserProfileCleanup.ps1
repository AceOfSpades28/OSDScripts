<# 
.SYNOPSIS 
Use Delprof2.exe to delete inactive profiles older than X days
tool from here: https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool
Permission was granted for Garytown.com to redistribute in content
.DESCRIPTION 
Gets Top Console user from ConfigMgr Client WMI, then runs delprof tool, excluding top console user list, 
and deletes any other inactive accounts based on how many days that you set in the -Days parameter.  
typical arugments;
        l   List only, do not delete (what-if mode) - Set by default
        u   Unattended (no confirmation) - Recommended to leave logs
        q   Quiet (no output and no confirmation)

.LINK
https://garytown.com
https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool - to see what arugments are available.
#> 

Param(
  [string]$Days = '365',
  [string]$argument = 'u'
)

$Logfile = "C:\temp\BFSlogs\UserProfileCleanup-$(get-date -f yyyy-MM-dd-hh-mm).log"
Start-Transcript -Path $Logfile -Append

$PrimaryUser = (Get-WmiObject -Namespace "root\cimv2\sms"-class sms_SystemConsoleUser).SystemConsoleUser 
#Change the path of DelProf2.exe to where you have it.  In my package, I have it in a subfolder called StorageCleanUp
.\StorageCleanUp\DelProf2.exe /ed:$PrimaryUser /d:$Days /$argument

Stop-Transcript