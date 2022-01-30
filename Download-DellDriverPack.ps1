<#	
	.NOTES
	===========================================================================
	 Created by:   	Adrian Allen
	 Organization: 	Builders First Source
	 Filename:     	Download-DellDriverPack.ps1
	===========================================================================
	.DESCRIPTION
		Dowlands & expands the latest Dell driver pack
#>

$DownloadFolder = "C:\Temp\DriverCache"
$DriverCatalog = "http://downloads.dell.com/catalog/DriverPackCatalog.cab"
$TargetModel = Get-WmiObject Win32_ComputerSystem | Select -Expand Model
$TargetOS = "Windows_10_x64"
$Logfile = "C:\Temp\DriverCache\Download-DellDriverPack-$(get-date -f yyyy-MM-dd-hh-mm).log"

Remove-Item -Path "$DownloadFolder" -Recurse -Force -Verbose -ErrorAction SilentlyContinue
	
# Create DownloadFolder if it does not exist
if (!(Test-Path $DownloadFolder))
{
	Try
	{
		New-Item -Path $DownloadFolder -ItemType Directory -Force | Out-Null
	}
	Catch
	{
		Write-Host "$($_.Exception)"
	}
}	

Start-Transcript -Path $Logfile

# Download Latest Catalog and Extract
if ($DriverCatalog -match "ftp" -or $DriverCatalog -match "http")
{		
	# Download Driver CAB for processing
	Write-Host "Downloading Catalog: $DriverCatalog"
	$wc = New-Object System.Net.WebClient
	$wc.DownloadFile($DriverCatalog, "$DownloadFolder\DriverPackCatalog.cab")
	if (!(Test-Path "$DownloadFolder\DriverPackCatalog.cab"))
	{
		Write-Host "Download Failed. Exiting Script."
		Exit
	}
		
	# Extract Catalog XML File from CAB
	Write-Host "Extracting Catalog XML to $DownloadFolder"
	$CatalogCABFile = "$DownloadFolder\DriverPackCatalog.cab"
	$CatalogXMLFile = "$DownloadFolder\DriverPackCatalog.xml"
	EXPAND $CatalogCABFile $CatalogXMLFile | Out-Null
		
}
else
{
	if (!(Test-Path -Path $DriverCatalog))
	{
		Write-Host "$DriverCatalog Does Not Exist!"
		Exit
	}
	else
	{
		$CatalogXMLFile = "$DownloadFolder\DriverPackCatalog.xml"
		Remove-Item -Path $CatalogXMLFile -Force -Verbose | Out-Null
		Write-Host "Extracting DriverPackCatalog.xml to $DownloadFolder"
		EXPAND $DriverCatalog $CatalogXMLFile | Out-Null
			
	}
}
	
Write-Host "Target Model: $TargetModel"
Write-Host "Target Operating System: $($TargetOS.ToString())"
	
	
# Import Catalog XML
Write-Host "Importing Catalog XML"
[XML]$Catalog = Get-Content $CatalogXMLFile
	
	
# Gather Common Data from XML
$BaseURI = "http://$($Catalog.DriverPackManifest.baseLocation)"
$CatalogVersion = $Catalog.DriverPackManifest.version
Write-Host "Catalog Version: $CatalogVersion"
	
	
# Create Array of Driver Packages to Process
[array]$DriverPackages = $Catalog.DriverPackManifest.DriverPackage
	
Write-Host "Begin Processing Driver Packages"
# Process Each Driver Package
foreach ($DriverPackage in $DriverPackages)
{
	#Write-Host "Processing Driver Package: $($DriverPackage.path)"
	$DriverPackageVersion = $DriverPackage.dellVersion
	$DriverPackageDownloadPath = "$BaseURI/$($DriverPackage.path)"
	$DriverPackageName = $DriverPackage.Name.Display.'#cdata-section'.Trim()
		
	if ($DriverPackage.SupportedSystems)
	{
		$Brand = $DriverPackage.SupportedSystems.Brand.Display.'#cdata-section'.Trim()
		$Model = $DriverPackage.SupportedSystems.Brand.Model.Display.'#cdata-section'.Trim()
	}
		
	# Check for matching Target Operating System
	if ($TargetOS)
	{
		$osMatchFound = $false
		$sTargetOS = $TargetOS.ToString() -replace "_", " "
		# Look at Target Operating Systems for a match
		foreach ($SupportedOS in $DriverPackage.SupportedOperatingSystems)
		{
			if ($SupportedOS.OperatingSystem.Display.'#cdata-section'.Trim() -match $sTargetOS)
			{
				#Write-Debug "OS Match Found: $sTargetOS"
				$osMatchFound = $true
			}
				
		}
	}
		
		
	# Check for matching Target Model (Not Required for WinPE)
	if ($TargetModel -ne "WinPE")
	{
		$modelMatchFound = $false
		If ("$Brand $Model" -eq $TargetModel)
		{
			#Write-Debug "Target Model Match Found: $TargetModel"
			$modelMatchFound = $true
		}
	}
		
		
	# Check Download Condition Based on Input (Model/OS Combination)
	if ($TargetOS -and ($TargetModel -ne "WinPE"))
	{
		# We are looking for a specific Model/OS Combination
		if ($modelMatchFound -and $osMatchFound) { $downloadApproved = $true }
		else { $downloadApproved = $false }
	}
	elseif ($TargetModel -ne "WinPE" -and (-Not ($TargetOS)))
	{
		# We are looking for all Model matches
		if ($modelMatchFound) { $downloadApproved = $true }
		else { $downloadApproved = $false }
	}
	else
	{
		# We are looking for all OS matches
		if ($osMatchFound) { $downloadApproved = $true }
		else { $downloadApproved = $false }
	}
		
		
	if ($downloadApproved)
	{
			
		# Create Driver Download Directory
		if ($Brand -and $Model)
		{
			$DownloadDestination = "$DownloadFolder\CAB"
		}
		else
		{
			$DownloadDestination = "$DownloadFolder\$sTargetOS"
		}
		if (!(Test-Path $DownloadDestination))
		{
			Write-Host "Creating Driver Download Folder: $DownloadDestination"
			New-Item -Path $DownloadDestination -ItemType Directory -Force | Out-Null
		}
			
			
		# Download Driver Package
		if (!(Test-Path "$DownloadDestination\$DriverPackageName"))
		{
			Write-Host "Beginning File Download: $DownloadDestination\$DriverPackageName"
			$wc = New-Object System.Net.WebClient
				
			if ($DontWaitForDownload)
			{
				$wc.DownloadFileAsync($DriverPackageDownloadPath, "$DownloadDestination\$DriverPackageName")
			}
			else
			{
				$wc.DownloadFile($DriverPackageDownloadPath, "$DownloadDestination\$DriverPackageName")
					
				if (Test-Path "$DownloadDestination\$DriverPackageName")
				{
					Write-Host "Driver Download Complete: $DownloadDestination\$DriverPackageName"	
				}
			}
		}
			
			
	}# Driver Download Section
		
}
	
Write-Host "Finished Processing Dell Driver Catalog"
Write-Host "Downloads will execute in the background and may take some time to finish"

# Expand Driver CAB
$cabfile = $DownloadFolder + "\CAB"
$expanded = $DownloadFolder + "\Expanded"
try {
    New-Item -Path $expanded -ItemType Directory -Force
    expand -f:* $cabfile\*.*  $expanded
    Write-Host "Finished expanding driver pack."
    }
    catch {Write-Error "$($_.Exception)"
    }

Stop-Transcript

# SIG # Begin signature block
# MIIh7QYJKoZIhvcNAQcCoIIh3jCCIdoCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBLpS5soKuQoyl2
# wNm9j+DIMwvrePguFQfzI3It5h9wxaCCHRMwggT+MIID5qADAgECAhANQkrgvjqI
# /2BAIc4UAPDdMA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNV
# BAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0EwHhcN
# MjEwMTAxMDAwMDAwWhcNMzEwMTA2MDAwMDAwWjBIMQswCQYDVQQGEwJVUzEXMBUG
# A1UEChMORGlnaUNlcnQsIEluYy4xIDAeBgNVBAMTF0RpZ2lDZXJ0IFRpbWVzdGFt
# cCAyMDIxMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwuZhhGfFivUN
# CKRFymNrUdc6EUK9CnV1TZS0DFC1JhD+HchvkWsMlucaXEjvROW/m2HNFZFiWrj/
# ZwucY/02aoH6KfjdK3CF3gIY83htvH35x20JPb5qdofpir34hF0edsnkxnZ2OlPR
# 0dNaNo/Go+EvGzq3YdZz7E5tM4p8XUUtS7FQ5kE6N1aG3JMjjfdQJehk5t3Tjy9X
# tYcg6w6OLNUj2vRNeEbjA4MxKUpcDDGKSoyIxfcwWvkUrxVfbENJCf0mI1P2jWPo
# GqtbsR0wwptpgrTb/FZUvB+hh6u+elsKIC9LCcmVp42y+tZji06lchzun3oBc/gZ
# 1v4NSYS9AQIDAQABo4IBuDCCAbQwDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQC
# MAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwQQYDVR0gBDowODA2BglghkgBhv1s
# BwEwKTAnBggrBgEFBQcCARYbaHR0cDovL3d3dy5kaWdpY2VydC5jb20vQ1BTMB8G
# A1UdIwQYMBaAFPS24SAd/imu0uRhpbKiJbLIFzVuMB0GA1UdDgQWBBQ2RIaOpLqw
# Zr68KC0dRDbd42p6vDBxBgNVHR8EajBoMDKgMKAuhixodHRwOi8vY3JsMy5kaWdp
# Y2VydC5jb20vc2hhMi1hc3N1cmVkLXRzLmNybDAyoDCgLoYsaHR0cDovL2NybDQu
# ZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC10cy5jcmwwgYUGCCsGAQUFBwEBBHkw
# dzAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME8GCCsGAQUF
# BzAChkNodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEyQXNz
# dXJlZElEVGltZXN0YW1waW5nQ0EuY3J0MA0GCSqGSIb3DQEBCwUAA4IBAQBIHNy1
# 6ZojvOca5yAOjmdG/UJyUXQKI0ejq5LSJcRwWb4UoOUngaVNFBUZB3nw0QTDhtk7
# vf5EAmZN7WmkD/a4cM9i6PVRSnh5Nnont/PnUp+Tp+1DnnvntN1BIon7h6JGA078
# 9P63ZHdjXyNSaYOC+hpT7ZDMjaEXcw3082U5cEvznNZ6e9oMvD0y0BvL9WH8dQgA
# dryBDvjA4VzPxBFy5xtkSdgimnUVQvUtMjiB2vRgorq0Uvtc4GEkJU+y38kpqHND
# Udq9Y9YfW5v3LhtPEx33Sg1xfpe39D+E68Hjo0mh+s6nv1bPull2YYlffqe0jmd4
# +TaY4cso2luHpoovMIIFBzCCAu+gAwIBAgIQd5sCHxFqlY5HZAVic0oxvzANBgkq
# hkiG9w0BAQsFADAWMRQwEgYDVQQDEwtCRlMtUm9vdC1DQTAeFw0xNjA5MTkxNjE4
# NDNaFw0zNjA5MTkxNjI4NDJaMBYxFDASBgNVBAMTC0JGUy1Sb290LUNBMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA2B9QJkFWOxryLUCykTlSHoyYAZD1
# rKVrP7MmwB8T6UpbV0BkWn3dOy4Rb3qz2KlWwn/HW0NIOOxlyAyZHOm0NBfjXWn2
# PJmkCQkIe/lT2cttCiyFc+lYZ7UnC2Hv1jq5jWO61jdkaCxB4l12YY0H59EUJMua
# N670pm2NkjazoIyelETo4KDRouPK7EmyCpQ7XGz3+5Drvpr8P1g/ZQUKrR5aLIdM
# Z/sQUDMRCI69OV9L4hmJXN+ED+JuvO7z4ww/A3Ny7kg+aQh9PK1o1I1RFrcvjRyC
# Sd+4n5pOmJoWhOUvkIup6pQ4tHxLM2Gpzy0hGfIARHbnie1lpBGrJykA9OioVD2g
# cHfYNOpKl5W7pniflvTAZ+nLjUNZ8AnA31Jbo8bCUFVV9mLocQHdp6ZtAe2Qi4Zk
# CF9/m9aRb3XyuCeHbVOgoU7TAHZxnckfjotw/KRZhYglrOU0lr6dxJ20hWihEJfd
# 8gIvCzBU/zDXRPY6L/rn2/na+3cujbOaRLbsBo4A/CKpOg5f+VjWpJZhOK6NiOrR
# D8K3+AWD+K0hDWENI2mRLhXoZiG5Hdj23qjTdZoT1HY/UBV6eZ7IYr2zvS1EWuhO
# x8H8ZoqkvDTq1dRrN9QNdCyrzX75ILpeHUDsnZjDvRp77vNTcD65uwUuEWt0NXdr
# o/bhzFDL1Xm4MLMCAwEAAaNRME8wCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMB
# Af8wHQYDVR0OBBYEFA6WbS9tgbYUA33+IlSCrFMRGJZnMBAGCSsGAQQBgjcVAQQD
# AgEAMA0GCSqGSIb3DQEBCwUAA4ICAQCRg19j/Ii3sMvrmUcF3L2TatKzrUQ7idSk
# FVEyTLsZVcNLzru3Wo7Hinx1TsocIu2fZi/Za9YHtKQeeJn8aRscs9cef+CKZw5w
# Di/uFmc62ANyytOTRDGkOrFhEjrssPN55gtqAmkgqXZVJ3tBiy0BFEcXAZBiBS/o
# QK1moA4Nvg84uIGD6fJUndh3X9pylFLjcm19Llzy5NFdt9qfLyGO2BGZP3RbRgRN
# 2QR0SS7mV8PvLUD8H0M2OHLakVeCw+ECtvMy16ZZXdUKhEnCbF5hNl8eupZ3U3QJ
# YbrALzCqvMrl9S6gAz40wSThG+yyCBMzT4WD1FU/gqlNFAdcY0TE+xJdrN8KSzCb
# 4yzzIlPDQOAkCLozDyrUiqBGMG42HZVJLSELKnJkO0CfzlItOkeOJnsE4DaBIeJe
# 8lr1uhrstKuFTlqCgacCWwJx72e1uZGE/Yt0fg4SW8zx793hl+Dx+Stddd+Ai5TB
# 6UVg6r6EAHMuAkgjqRacYW9PGQxB0mF+cLLrnJ0JiLhlcSSFYyp+r/0czBHLzHul
# FjzON16hVDZ0I5EgqmCmUsygg4/ELZorgpQsZzIDRwA219/fs5b/6+2wFacecNis
# VUOx9ncabT76+de3ji9Ay3jUs/w81TUUcChPyRgrJfFDB1WJrP3uCu1BKEcHaMxq
# tAsm8hEMQjCCBTEwggQZoAMCAQICEAqhJdbWMht+QeQF2jaXwhUwDQYJKoZIhvcN
# AQELBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcG
# A1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJl
# ZCBJRCBSb290IENBMB4XDTE2MDEwNzEyMDAwMFoXDTMxMDEwNzEyMDAwMFowcjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElE
# IFRpbWVzdGFtcGluZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# AL3QMu5LzY9/3am6gpnFOVQoV7YjSsQOB0UzURB90Pl9TWh+57ag9I2ziOSXv2Mh
# kJi/E7xX08PhfgjWahQAOPcuHjvuzKb2Mln+X2U/4Jvr40ZHBhpVfgsnfsCi9aDg
# 3iI/Dv9+lfvzo7oiPhisEeTwmQNtO4V8CdPuXciaC1TjqAlxa+DPIhAPdc9xck4K
# rd9AOly3UeGheRTGTSQjMF287DxgaqwvB8z98OpH2YhQXv1mblZhJymJhFHmgudG
# UP2UKiyn5HU+upgPhH+fMRTWrdXyZMt7HgXQhBlyF/EXBu89zdZN7wZC/aJTKk+F
# HcQdPK/P2qwQ9d2srOlW/5MCAwEAAaOCAc4wggHKMB0GA1UdDgQWBBT0tuEgHf4p
# rtLkYaWyoiWyyBc1bjAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAS
# BgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggr
# BgEFBQcDCDB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3Nw
# LmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHoweDA6
# oDigNoY0aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNybDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0QXNzdXJlZElEUm9vdENBLmNybDBQBgNVHSAESTBHMDgGCmCGSAGG/WwAAgQw
# KjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzALBglg
# hkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggEBAHGVEulRh1Zpze/d2nyqY3qzeM8G
# N0CE70uEv8rPAwL9xafDDiBCLK938ysfDCFaKrcFNB1qrpn4J6JmvwmqYN92pDqT
# D/iy0dh8GWLoXoIlHsS6HHssIeLWWywUNUMEaLLbdQLgcseY1jxk5R9IEBhfiThh
# TWJGJIdjjJFSLK8pieV4H9YLFKWA1xJHcLN11ZOFk362kmf7U2GJqPVrlsD0WGkN
# fMgBsbkodbeZY4UijGHKeZR+WfyMD+NvtQEmtmyl7odRIeRYYJu6DC0rbaLEfrvE
# JStHAgh8Sa4TtuF8QkIoxhhWz0E0tmZdtnR79VYzIi8iNrJLokqV2PWmjlIwggbf
# MIIFx6ADAgECAhNbAADyYqclx5pALMYpAAAAAPJiMA0GCSqGSIb3DQEBCwUAMGsx
# EzARBgoJkiaJk/IsZAEZFgNjb20xIzAhBgoJkiaJk/IsZAEZFhNidWlsZGVyc2Zp
# cnN0c291cmNlMRMwEQYKCZImiZPyLGQBGRYDYmZzMRowGAYDVQQDExFCRlMtSXNz
# dWluZy1DQS0wMTAeFw0xOTA5MDUxNjU0MzVaFw0yMjA5MDQxNjU0MzVaMIGpMRMw
# EQYKCZImiZPyLGQBGRYDY29tMSMwIQYKCZImiZPyLGQBGRYTYnVpbGRlcnNmaXJz
# dHNvdXJjZTETMBEGCgmSJomT8ixkARkWA2JmczESMBAGA1UECxMJTG9jYXRpb25z
# MQswCQYDVQQLEwJUWDEgMB4GA1UECxMXRGFsbGFzIENvcnBvcmF0ZSBPZmZpY2Ux
# FTATBgNVBAMTDEFkcmlhbiBBbGxlbjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBALzYuvjrYTLG6Y7nNUQq0bIoixAfXvEUJ93TZuYrfuDOI3tC9M5BHJQF
# j7KEgfAELKHuXrD+f2ROfwWa8sB0KtpqZuWkjmC+6PIoLgiy0o0LRm0sg29kJ0nr
# 1RV3agkjyZVPczMA8DXFTVAPzhhtWeGlohu44+8rnst1sCyNm1Yjho/TmsN6TzpV
# oVBqud0VBoWrghWKLafJ9dXxu7YEU9g43V1iIEvyaPrKUHOMhW/WtAuYE4kzBSWr
# Y5o+v8/WEYMFVraZfUc+oi4/TzWQlrbLMwSGEBZu2EvULYNAJH5QRFdxTOR4ZXGA
# S4Gkf2nH3esCtCyqJ41r5NHZwS7Xp3UCAwEAAaOCAzswggM3MD4GCSsGAQQBgjcV
# BwQxMC8GJysGAQQBgjcVCIbdlwWD6JQbh4mTE4SXpVmClLVPgSCHh8MlgcDkSQIB
# ZAIBGzAVBgNVHSUEDjAMBgorBgEEAYI3CgMMMAsGA1UdDwQEAwIGwDAdBgkrBgEE
# AYI3FQoEEDAOMAwGCisGAQQBgjcKAwwwHQYDVR0OBBYEFCv3Lqw3Ts244yyQDLG+
# 6DvOC1AmMB8GA1UdIwQYMBaAFN07p3/NU0PVFJULVf5i8EpG1kLAMIIBKgYDVR0f
# BIIBITCCAR0wggEZoIIBFaCCARGGQGh0dHA6Ly9wa2kuYmZzLmJ1aWxkZXJzZmly
# c3Rzb3VyY2UuY29tL1BLSS9CRlMtSXNzdWluZy1DQS0wMS5jcmyGgcxsZGFwOi8v
# L0NOPUJGUy1Jc3N1aW5nLUNBLTAxLENOPURBTFBLSTAxLENOPUNEUCxDTj1QdWJs
# aWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9u
# LERDPWJmcyxEQz1idWlsZGVyc2ZpcnN0c291cmNlLERDPWNvbT9jZXJ0aWZpY2F0
# ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9u
# UG9pbnQwggEQBggrBgEFBQcBAQSCAQIwgf8wNwYIKwYBBQUHMAGGK2h0dHA6Ly9w
# a2kuYmZzLmJ1aWxkZXJzZmlyc3Rzb3VyY2UuY29tL29jc3AwgcMGCCsGAQUFBzAC
# hoG2bGRhcDovLy9DTj1CRlMtSXNzdWluZy1DQS0wMSxDTj1BSUEsQ049UHVibGlj
# JTIwS2V5JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixE
# Qz1iZnMsREM9YnVpbGRlcnNmaXJzdHNvdXJjZSxEQz1jb20/Y0FDZXJ0aWZpY2F0
# ZT9iYXNlP29iamVjdENsYXNzPWNlcnRpZmljYXRpb25BdXRob3JpdHkwMAYDVR0R
# BCkwJ6AlBgorBgEEAYI3FAIDoBcMFWFkcmlhbi5hbGxlbkBibGRyLmNvbTANBgkq
# hkiG9w0BAQsFAAOCAQEAaTFdrpIcy49AR330ZiKij/H4VUrHQelzAZiCTaEZxCik
# MUENuA0nsRi+w/ASQ622wHSfNKdlQYbF7pZI+xlfxh6D+9d1kyipvmzs0tSlrmEz
# taJaWwE5Mdt3IbPDz74+k/Qr9pmlCU7uUq7+3WF+Fwfh/t2ZK8TbTeiHile/JaJx
# wn8QlkpPvUvhDycPczEVbbqZf7jNf3VTVL6S93t2SyE/xzVYovhMgUgHCRF1Eit1
# M5N/5INMFbZ0V5uVgGNRpPry68KV6oOSw2NWrhBBfHizbufmGugVDsBXKwqTos33
# AyrGbySXyb5LbHZicMg+hCRzmhRLH/8lX/VAHcdMFzCCBuowggTSoAMCAQICE0YA
# AAAChG+8caLTHSgAAAAAAAIwDQYJKoZIhvcNAQELBQAwFjEUMBIGA1UEAxMLQkZT
# LVJvb3QtQ0EwHhcNMTYwOTIxMTM1NTAyWhcNMzYwOTE5MTYyODQyWjBrMRMwEQYK
# CZImiZPyLGQBGRYDY29tMSMwIQYKCZImiZPyLGQBGRYTYnVpbGRlcnNmaXJzdHNv
# dXJjZTETMBEGCgmSJomT8ixkARkWA2JmczEaMBgGA1UEAxMRQkZTLUlzc3Vpbmct
# Q0EtMDEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDPGayJb4c6dKxJ
# oBNIyfiXMkQwOOo+cE6O5Aqx6hRIKLXsUpDQZnH4kdtrj6FpTogrQ42W0+GExDMk
# xhAFmpCwnkub7WQw6DP2bvWlppQDCRpFmaJEQ2ZOpcVtfwkgVPPgtWZPCTnq+e9g
# OPdm3kwLmCzqxbWIGGFmLvnsfVDi8qENOMSXs6Cx2qmh2etTH712f2f1uh0KSU+a
# QY6gT2iRqKlrrZSt6S2o2x+Z8HFdAiewYsQ5Ft9lsKaX3vo9RK8TzrsoKdBnyGVY
# hnFZbxvM53LmsxHrGjG815enuacdQAXeaFay+DQCLZVF+gB4LNra0TUnFaLA/0/c
# GqjlJP23AgMBAAGjggLaMIIC1jAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU
# 3Tunf81TQ9UUlQtV/mLwSkbWQsAwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEw
# CwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAUDpZtL22B
# thQDff4iVIKsUxEYlmcwggEfBgNVHR8EggEWMIIBEjCCAQ6gggEKoIIBBoY6aHR0
# cDovL1BLSS5iZnMuYnVpbGRlcnNmaXJzdHNvdXJjZS5jb20vUEtJL0JGUy1Sb290
# LUNBLmNybIaBx2xkYXA6Ly8vQ049QkZTLVJvb3QtQ0EsQ049REFMUk9PVENBLENO
# PUNEUCxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1D
# b25maWd1cmF0aW9uLERDPWJmcyxEQz1idWlsZGVyc2ZpcnN0c291cmNlLERDPWNv
# bT9jZXJ0aWZpY2F0ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JM
# RGlzdHJpYnV0aW9uUG9pbnQwggEkBggrBgEFBQcBAQSCARYwggESMFAGCCsGAQUF
# BzAChkRodHRwOi8vUEtJLmJmcy5idWlsZGVyc2ZpcnN0c291cmNlLmNvbS9QS0kv
# REFMUk9PVENBX0JGUy1Sb290LUNBLmNydDCBvQYIKwYBBQUHMAKGgbBsZGFwOi8v
# L0NOPUJGUy1Sb290LUNBLENOPUFJQSxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNl
# cyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPWJmcyxEQz1idWlsZGVy
# c2ZpcnN0c291cmNlLERDPWNvbT9jQUNlcnRpZmljYXRlP2Jhc2U/b2JqZWN0Q2xh
# c3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTANBgkqhkiG9w0BAQsFAAOCAgEApZmX
# qr7a24FB+5gD6T2+yP0x6JOVnkVS4xkqIYCbsgAyR5Jsmx7HPOcEfqmGtHoWJfWQ
# 1hHLiqgQNyfI9E75gCadhAfSt8SImPH7fK6mN2Q3EkXm+E4X9s4qKM3XN4QphQW2
# nVa79VU7peRw3HMLHjcLeQLwzNiRMBtWCJpvzMg+1lj0vRiPYfkkFh3W2SpTGwJg
# Qb3tYTk5X1RxDnxDqb6Wao8xr0t2TwD9o0CES1TO/WwJsazGpHd8qjjE6a+f03+p
# tTsGOVd4nSASkc0ePV6I8n+hszn3Lo4ONqONgTJkwt5YejzQz6gM/iAqqbgsZbfI
# BCKjxd/P0VtEKfTYLaziFRbrEUm5PdoJNHRqNru4kPuz4T/r4goSup+hv7TrN71T
# 775Oen4U4AgLyLII9bg8F2VPGFDzaT/ZVOS9DZ8LM3WZGfQQyyP9pQgxof50x5QQ
# CEqESf/H/ic7C/kD+ua5EVofIhI0f2Ntb/N0uNl/EJX7I7E0faICIn+T1eitiW20
# LJXsy80itDy1V6uZFmtIX0CLc5GhGWwR9+1aqdl96BNr1OfumtPU1dZ/CDn+uBCl
# gcALYLOlvEsZMzc7SNjlt+GfmFcEieAJ4QN58US7Wrw0snp+TClscqMbUAMzg8fy
# vLeQQoNvO2er7pwsnrE6tCklKYoxa4RwdcTRicoxggQwMIIELAIBATCBgjBrMRMw
# EQYKCZImiZPyLGQBGRYDY29tMSMwIQYKCZImiZPyLGQBGRYTYnVpbGRlcnNmaXJz
# dHNvdXJjZTETMBEGCgmSJomT8ixkARkWA2JmczEaMBgGA1UEAxMRQkZTLUlzc3Vp
# bmctQ0EtMDECE1sAAPJipyXHmkAsxikAAAAA8mIwDQYJYIZIAWUDBAIBBQCgTDAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQg1HXdZIbP
# cYedKARU0g0GFhMEnD4IkoMPGXm10qUSmucwDQYJKoZIhvcNAQEBBQAEggEAd+VA
# Qv3Jpl3ovXWLi1CarlYIkUJ0qJEHaMAdi/oMY9/y3ULTxo7ciO1ceb3Sk4l5PfOD
# yCp1A4a1XB6hE9hJsi/EM4Fc0t/EZEAMtxwzRmbWZziwiLopvHzj0iU+8mQWcWgo
# Y+q7FhE6WHeQMe9NA3eT2oLvYUVQK9afS6JXXrftWe2aqQ09XGQio1goPe3cxd0q
# iShxrmzY9lioYuJFQtLzvt4NLKiV3pI8GGMi3jHdwvs1k2dHF1HxL5+spz2l/n3/
# N3/hoZnJZi+rGUonZz93H+c40q0PA7kIqLGYlS3HQjaVTAnHdULIpvUHhEQfvXQ6
# ON5KcCl4cW3XQwD6V6GCAjAwggIsBgkqhkiG9w0BCQYxggIdMIICGQIBATCBhjBy
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQg
# SUQgVGltZXN0YW1waW5nIENBAhANQkrgvjqI/2BAIc4UAPDdMA0GCWCGSAFlAwQC
# AQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcN
# MjIwMTE3MDQyODAzWjAvBgkqhkiG9w0BCQQxIgQgfPkjts4/CJJHjuW7KUFl8yfd
# a+1EbtC/QZq5Y2KPMjkwDQYJKoZIhvcNAQEBBQAEggEAsW6MxckTP+rBbTGVPygD
# FHSyXr7Hbt2jaXg3Emnpi7wxIUK/oiLdR4NxtnKcYAcT0JK0E5mYqc36hVPbAknR
# QZsHGaYGMB4ZP9Ua60ot5AkzFjDRs9wfSTd6o45IortQu5hlW2rUJuYxSUN/KHRE
# 2npLRpyAu2yoo+wBJq7SfYSwVS9CRtJfYXtnb0k83gFBogXOnFCL3d27YFhVgt1N
# w7iKMjPxhbRJI/ULZ7wjHnL1tjAjbtcJdZ4C/5BdLx8jEJzy6dFvjInmLMzdKxYF
# amd3pB0BZqQT7vzZs3Xckwby33+ef0tSKmM3paxgLX+qrzULh6KudEMUJ203KmIF
# 4w==
# SIG # End signature block
