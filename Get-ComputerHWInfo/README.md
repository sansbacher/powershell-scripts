Displays Computer Hardware Info

**Get-ComputerHWInfo.ps1**

- Gets all the info from WMI
- Works on Server 2003+ / Win XP+
- Outputs a .TXT file with all the info, you can specify a name on the cmdline, or it will auto-generate based on computer name
  
WHY? Years ago I found that LabTech RMM (now ConnectWise Automate) didn't always grab all the info I needed correctly, and if I had to rebuild a server/VM from backups I needed to know some important things such number of CPUs/Cores, amount of RAM, the NIC's IP and MAC Address, size of the Hard Drive, etc.

This script filled that gap - if you're going to do a V2V or P2V: run this first and save it.