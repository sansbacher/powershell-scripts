# Shows hardware and OS details from a PC/VM
# Labtech doesn't report all of this info, or sometimes reports it incorrectly
# This file could be tweaked to output to CSV, XML or a text file, or it can just be redirected to a file (which it does)
# ADD: CD-ROM info and iSCSI drive info!
#
# Last Updated May 22, 2017 by Saul Ansbacher

# param needs to be first executable line
param (
	#OutputFile name, plaintext; enclose in quotes if it has spaces, no extension added.
	# If NO name provided, generate one based on: COMPUTERNAME_WMI-HW.txt
	[string]$OutputFile = $( (gci env:computername).value+"_WMI-HW.txt" )
)

# Declearation before evaluation
Set-PSDebug -Strict 

write  "---------- COLLECTING HARDWARE INFO ----------"

# Collect some WMI data
$computerSystem = get-wmiobject Win32_ComputerSystem
$computerBIOS = get-wmiobject Win32_BIOS
$computerRAM = get-wmiobject Win32_PhysicalMemory  # Lists multiple memory sticks
$computerOS = get-wmiobject Win32_OperatingSystem
$computerCPU = get-wmiobject Win32_Processor
$computerHDD = Get-WmiObject Win32_LogicalDisk -Filter drivetype=3  # Type 3 = local drives only, no CD-ROMs, etc
$computerIDE = get-wmiobject Win32_IDEController 
$computerSCSI = get-wmiobject Win32_SCSIController  # could be several controllers
$computerUSBctrl = get-wmiobject Win32_USBController
$computerUSBdevice = get-wmiobject Win32_USBControllerDevice
$computerNIC = Get-WmiObject Win32_NetworkAdapterConfiguration -filter "IPenabled=True" # lists multiple NICs
# $computerPorts = Get-WmiObject -Class Win32_SerialPort  # multiple COM ports, not used

# START wrapping all of this so it can be easily redirected.
$(
	# These are all single value items:
	"ComputerName: " + $computerSystem.Name
	"Domain: " + $computerSystem.Domain
	"CollectionDate: " + (Get-Date)

	"OperatingSystem: " + $computerOS.caption + " " + $computerOS.OSArchitecture + " SP: " + $computerOS.ServicePackMajorVersion + " (Version: " + $computerOS.version + ")"
	"OSSystemDrive: " + $computerOS.SystemDrive
	"LoggedInUser: " + $computerSystem.UserName
	"LastReboot: " + $computerOS.ConvertToDateTime($computerOS.LastBootUpTime)

	"Manufacturer: " + $computerSystem.Manufacturer
	"Model: " + $computerSystem.Model + " (BIOS: " + $computerBIOS.SMBIOSBIOSVersion + ")"
	"SerialNumber: " + $computerBIOS.SerialNumber
	# TODO: Add KVM, etc helper versions for other Hypervisors
	if ($computerSystem.Manufacturer -like '*VMware*') {
		if (test-path "C:\Program Files\VMware\VMware Tools\VMToolsd.exe") {
			"VMwareTools: " + (GCM "C:\Program Files\VMware\VMware Tools\VMToolsd.exe" | foreach {$_.Fileversioninfo}).FileVersion
		} else { 	# VMware VM but no VMware tools
			write "VMwareTools: -- NOT FOUND --"
		}
	}
	if ($computerSystem.Manufacturer -like '*Microsoft*') {
		if (test-path "$ENV:windir\system32\ICSvc.dll") {		# MS Hyper-V 2012 ?
			"MSIntegrationServices: " + (GCM "$ENV:windir\system32\ICSvc.dll" | foreach {$_.Fileversioninfo}).FileVersion
		} elseif (test-path "$ENV:windir\system32\vmicsvc.exe")  {		# MS Hyper-V 2008 ?
			"MSIntegrationServices: " + (GCM "$ENV:windir\system32\vmicsvc.exe" | foreach {$_.Fileversioninfo}).FileVersion
		} else { 		# MS Hyper-V VM but no Integration Services
			write "MSIntegrationServices: -- NOT FOUND --"
		}
	}
	if ($computerSystem.Manufacturer -like '*Xen*') {
		if (test-path "$ENV:windir\system32\liteagent.exe") {   # Lite Tools, not positive on this but it's a System Service
			"XenToolsLite: " + (GCM "$ENV:windir\system32\liteagent.exe" | foreach {$_.Fileversioninfo}).ProductVersion
		} else { 	# Xen VM but no XenTools
			write "XenTools: -- NOT FOUND --"
		}
		if (test-path "C:\Program Files (x86)\Citrix\XenTools\XenGuestAgent.Exe")  {		# Proper XenTools
			"XenToolsGuestAgent: " + (GCM "C:\Program Files (x86)\Citrix\XenTools\XenGuestAgent.Exe" | foreach {$_.Fileversioninfo}).FileVersion
		} elseif (test-path "C:\Program Files\Citrix\XenTools\XenGuestAgent.Exe")  {		# Proper XenTools, just in case x64 one day
			"XenToolsGuestAgent: " + (GCM "C:\Program Files\Citrix\XenTools\XenGuestAgent.Exe" | foreach {$_.Fileversioninfo}).FileVersion
		} elseif (test-path "C:\Program Files (x86)\Citrix\XenTools\XenService.Exe")  {		# Older XenTools
			"XenToolsGuestAgent: " + (GCM "C:\Program Files (x86)\Citrix\XenTools\XenService.Exe" | foreach {$_.Fileversioninfo}).FileVersion
		} elseif (test-path "C:\Program Files\Citrix\XenTools\XenService.Exe")  {			# Older XenTools, just in case x64...
			"XenToolsGuestAgent: " + (GCM "C:\Program Files\Citrix\XenTools\XenService.Exe" | foreach {$_.Fileversioninfo}).FileVersion
		} else {  # No Guest Agent
			write "XenToolsGuestAgent: -- NOT FOUND --"
		}
	}
	# If more than 1 physical CPU assume they are all identical, report only the 1st element
	$NumCPUs = @($computerCPU).count		# force an array for PS 2.0
	if ( $NumCPUs -gt 1 ) {
		"CPU: " + $computerCPU[0].Name + " (" +  $computerCPU[0].Description + ")"
		"CPUProcessors: " + $NumCPUs
		"CPUPhysicalCoresPerProc: " + $computerCPU[0].NumberOfCores
		"CPULogicalCoresPerProc: " + $computerCPU[0].NumberOfLogicalProcessors
		"WindowsTotalCores: " + $NumCPUs * $computerCPU[0].NumberOfLogicalProcessors
	} else {   # Only 1 CPU, but Name[0] would therefore reference the first character of the string, not the first element of the array
		"CPU: " + $computerCPU.Name + " (" +  $computerCPU.Description + ")"
		"CPUProcessors: " + $NumCPUs
		"CPUPhysicalCoresPerProc: " + $computerCPU.NumberOfCores
		"CPULogicalCoresPerProc: " + $computerCPU.NumberOfLogicalProcessors
		"WindowsTotalCores: " + $NumCPUs * $computerCPU.NumberOfLogicalProcessors
	}
	# Windows and Physical RAM doesn't always match, esp. on 32 bit systems in LabTech:
	"WindowsRAM: " + "{0:N1}" -f ($computerSystem.TotalPhysicalMemory/1GB) + "GB"
	$totalRAM=0; foreach ($stick in $computerRAM) {$totalRAM += $stick.Capacity} 
	"PhysicalRAM: " + "{0:N1}" -f ($totalRAM/1GB) + "GB"
	 
	write " "

	# These items are potentially arrays of multiple values:

	# These ones are only good if there is a single local drive:
	#"HDDSize: "  + "{0:N2}" -f ($computerHDD.Size/1GB) + "GB"
	#"HDD Space: " + "{0:P2}" -f ($computerHDD.FreeSpace/$computerHDD.Size) + " Free (" + "{0:N2}" -f ($computerHDD.FreeSpace/1GB) + "GB)"
	#"HDDFree: " + "{0:N2}" -f ($computerHDD.FreeSpace/1GB) + "GB"
	if ( $computerHDD.count -gt 1 ) {		# Multiple drives, get a total for all
		# For some reason the $array.item | measure -sum  method (see below) didn't work on all machines (and not all just 1 type of machine)
		# so resortig to pre-calculating the totals ahead of time here:
		$tmpFreeSpc = 0 ; $tmpSize = 0
		foreach ($drive in $computerHDD) {$tmpFreeSpc += $drive.Freespace ; $tmpSize += $drive.Size}
		# New "drive" object to be added to the drive list fro Totals
		$tempTotal = New-Object -TypeName PSObject -Property @{
			DeviceID = "-TOTAL-"
			DriveType = 99	# Dummy value. Normal values range from 0 to 6
			ProviderName = $null
			## For some reason this works on some machines but fails on others:
			# FreeSpace = ($computerHDD.FreeSpace | measure -sum).sum
			# Size = ($computerHDD.Size | measure -sum).sum
			## So pre-calcuating the totals seems to work:
			FreeSpace = $tmpFreeSpc
			Size = $tmpSize
			VolumeName = $null
		}
		$computerHDD += $tempTotal	# Adding it as another "drive" just makes it easy, but be careful if re-using $computerHDD later in this script!
	}
	write "HardDrives: "
	$computerHDD | select DeviceID, VolumeName, @{Label="SizeInGB";Expression= {[math]::truncate($_.size / 1GB)}}, @{Label="UsedSpaceInGB";Expression= {[math]::truncate(($_.size - $_.freespace) / 1GB)}}, @{Label="FreeSpaceInGB";Expression= {[math]::truncate($_.freespace / 1GB)}} | ft -auto

	# Report IDE and SCSI together
	write "HDDControllers: "
	$SCSIcontrollers = $computerSCSI | select Manufacturer,DriverName,description
	$IDEcontrollers = $computerIDE | select Manufacturer,DriverName,description | where { $_.Manufacturer -notlike '*standard*'}
	$IDEcontrollers,$SCSIcontrollers | ft * -auto

	# If we wanted to exclude IPv6 but include multiple IPv4 IPs this might be useful
	# foreach ($nic in $computerNIC) { $nic.IPAddress | where { $_ -notmatch ":"} }
	# All we really want is to see the type of NIC and the MAC
	write "NetworkCards: "
	$computerNIC | select Description, ServiceName, MACAddress, DHCPEnabled,@{Label="IPAddress";Expression={$_.IPAddress[0]}}, @{Label="DefaultGateway";Expression={[string]$_.DefaultIPGateway}} | ft -auto

	# Not useful, reports COM ports whether or not a VM on VMWare has them or not.
	#write "SerialPorts: "
	#$computerPorts | select DeviceID, Description, MaxBaudRate | ft -auto

	write "USBControllers: "
	if ($computerUSBctrl -eq $null) {
		write "-- none --"
	} else {
		$computerUSBctrl | select Manufacturer,Description | ft -auto
		
		# If we have a controller look for devices
		write "USBDevices: "
		$computerUSBdevice | foreach {[wmi]($_.Dependent)} | where {$_.Manufacturer -notlike '*generic*' -and  $_.Manufacturer -notlike '*standard*' -and  $_.Manufacturer -notlike '*Microsoft*'} | select Manufacturer, Service, Description | ft -auto
	}

	write " "
# END-wrapping, and output everything to specified file, truncating at 250 characters
) | out-string -width 250 | out-file -filePath $OutputFile

write-host "---------- Output saved to: $OutputFile"
