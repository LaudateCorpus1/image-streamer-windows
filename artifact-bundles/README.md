# Image Streamer artifacts for Microsoft Windows Server 2016/2019 and Hyper-V Server 2016/2019

## Version History

HPE - Windows - 2019-07-16

  - Fixed - server-profile creation failure using Management NIC 'User defined' option
  
HPE - Windows - 2018-10-26

  - Windows artifact bundle for both 2016 and 2019
  
## Supported Image Streamer versions
The artifacts are supported on Image Streamer 4.1 and higher for 2016, 4.2 and higher for 2019.     

## Golden Image Creation
1.	Ensure that you have access to Windows 2016 or 2019 ISO file.

1.	Create a server profile with “HPE - Foundation 1.0 - create empty OS Volume” as OS Deployment plan and a server hardware of desired hardware type (see section on Golden Image Compatibility below). Set an appropriate value for volume size in MiB units, say 40000 MiB. The HPE Synergy Server will be configured for access to this empty OS Volume.

1.	Launch iLO Integrated Remote Console of this server and set the Windows 2016 or 2019 ISO file as virtual CD-ROM/DVD image file. Power on the server.

1.  Windows should present an option of installing from CD/DVD. Continue with this option.

1.  Install Windows 2016 or 2019.

1.  (Optional) To take a backup of this installation:
  
    1.  Shutdown the server

    1.  Perform an as-is capture using "HPE - Windows - Capture - As-Is" build plan to create the "as-is" golden image of the OS.

    1.  Deploy another server with the golden image captured in previous step and boot the server.

1.  Install any additional software or roles if required.

    **NOTE:** The next six steps can be automated using the “PrepareForImageStreamerOSVolumeCapture.ps1” script in “scripts” directory on the github repository where Windows artifact bundles are available for download. 

1.  Create a FAT32 partition which will be used by the artifacts for personalization:
FAT 32 partition can be created either from UI using Disk Management utility (i) or using CMD Diskpart commands (ii). 
     
    1.   FAT32 partition creation from UI
    
          1.   Open "Computer Management" > "Disk Management"
          1.   Select C: partition
          1.   Shrink volume
          1.   Change amount of space to shrink to 100 MB
          1.   Select Shrink
          1.   Select new Unallocated space
          1.   Select New Simple Volume
          1.   Leave size
          1.   Assign drive letter (Choose S)
          1.   Format as FAT32 file system type (this requires changing from the default)
          1.   Give Volume label as "ISDEPLOY"
          1.   Finish
          1.   “ISDEPLOY (S:)” should be shown
    
    1.   FAT32 partition creation using CMD commands.
         
         Use list volume command to get volume number for C: partition. Here C: partition resides in Volume 0.
         
             C:\Users\Administrator>diskpart
             DISKPART>list volume
             DISKPART >select volume 0
             DISKPART >shrink desired=100
             DISKPART >create partition primary size=100
             DISKPART >format fs=fat32 quick label=ISDEPLOY
             DISKPART >assign letter=S                
         
   
1.  Backup drive-letters

        reg export HKLM\System\MountedDevices C:\driveletters.reg
 
1.  Generalize Windows

    **WARNING:** This operation is destructive and will remove all configuration. To take backup of the system at this stage, capture an as-is golden image. 

    Open Command Prompt window and run the following:

        cd \Windows\System32\Sysprep
        Sysprep /generalize /oobe /quit

    This will take a few minutes to complete and will generalize the system. All settings will be lost. This does not remove any additional user accounts that are created. Any user accounts not required in the captured golden image must be manually deleted.  


1.  Restore drive-letters 

        reg import C:\driveletters.reg

1.  Set Unattend.xml location to the FAT32 partition

        reg add HKLM\System\Setup /v UnattendFile /t REG_SZ /d "S:\ISdeploy\Unattend.xml"

1. Set SetupComplete.cmd location to the FAT32 partition.   

    Run the following in the Windows Command prompt (cmd.exe). Do not run it in PowerShell as it may add special characters which will cause personalization to fail.

        mkdir C:\Windows\Setup\Scripts

        echo S:\ISdeploy\SetupComplete.cmd > C:\Windows\Setup\Scripts\SetupComplete.cmd

    **OR** Run the following in PowerShell prompt 

        mkdir C:\Windows\Setup\Scripts

        Set-Content -Value "S:\ISdeploy\SetupComplete.cmd" -Path $env:windir\Setup\Scripts\SetupComplete.cmd


1.  Shutdown the server.

1.  Capture a golden image using the "HPE - Windows - Capture - As-Is" build plan. This will be the generalized golden image.


## Golden Image Compatibility
The golden image created using the above method will work only on server hardware of the same model (for example: Synergy 480 Gen9) containing same number of processors. If the server hardware is of different model or contains different number of processors, or if the boot controller is moved from one Mezzanine/slot to another, Windows will be unable to boot on the deployed server hardware.

## Pagefile Size
Following is recommended for the size and location of the pagefile:

   - If the pagefile is going to be of small size (< 1 GiB), then it can be located on the OS volume.
   - If the pagefile is going to be large (> 1 GiB), then it should be located on local disk or SAN and configured appropriately.
   - If a large pagefile size is required and the above recommendations cannot be followed, then using Windows with Image Streamer may require re-consideration as having a large pagefile on the OS volume may consume significant storage on Image Streamer and limit the number of server profiles that can be deployed.       

## Deployment
Use a deployment plan with the "HPE - Windows - Deploy" build plan and a generalized golden image (captured in previous steps).

---

## Plan scripts for Windows personalization
The plan scripts used for deployment use two methods for personalization:

  - **Unattend.xml.**
    This is an answer file that stores the custom settings that are applied during Windows setup. 
  - **SetupComplete.cmd script.**
    This is a script where commands can be added to run at the end of Windows setup.

Plan scripts can generate parts of Unattend.xml and/or generate scripts to run from SetupComplete.cmd. 

### Plan Script directory conventions
  - **/ISdeploy/SetupComplete**
    Scripts created in this directory will be executed through SetupComplete.cmd in alphabetical order (more details below)
  - **/ISdeploy/Unattend**
    Unattend.xml will be generated based on files and directories in this location (more details below)
  - **/ISdeploy/Scripts**
    Scripts executed by Unattend.xml or other scripts are created here
  - **/ISdeploy/Files**
    Files used by any scripts are created here
  - **/ISdeploy/Temp**
    Temporary files and scripts created during personalization are stored at this location. These are deleted after personalization is completed

### Unattend.xml conventions

  - Temporary directory (TMPDIR) used by "HPE - Windows - Unattend - Save" is **/ISdeploy/Unattend/**
  - "HPE - Windows - Unattend - Save" script generates the entire Unattend.xml based on the parts generated by other scripts. This script must be added just before the "HPE - Windows - Unattend - Debug" (if included) and "HPE - Windows - Unmount" steps in OS Build Plan.
  - If a pass is to be included in Unattend.xml, TMPDIR/*pass* directory should exist. For example: For specialze and oobeSystem passes, "/ISdeploy/Unattend/specialize" and "/ISdeploy/Unattend/oobeSystem" directories must be created by a plan script.
  - If a component is to be included, TMPDIR/*pass*/*component* directory should exist. For example: /ISdeploy/Unattend/specialize/Microsoft-Windows-Shell-Setup
  - If TMPDIR/*pass*/*component*.xml file exists, it is considered as the contents of start tag of that component. If it doesn't exist, start tag is automatically generated.
  - TMPDIR/*pass*/*component* directory can contain directories or files. Directories are used for nested elements inside components. For example: oobeSystem > Microsoft-Windows-Shell-Setup > UserAccounts > LocalAccounts
  - Contents of all files (preferably created having .xml extension) are added inside the component XML. This is done in alphabetical order of filenames (as listed by the "ls" command in Linux). 
  - If any directories exist in TMPDIR/*pass*/*component*/, the names are considered as element names. An element is added in the XML for each directory name. These directories can have further levels of nesting and directories at all levels can contain .xml files.
  - The .xml filenames should preferably match the element name whose XML they contain. In case an element has nested elements, then care should be taken to ensure that one plan script does not overwrite the XML file or other files created by another plan script. 
  - "HPE - Windows - Unattend - Save" will recursively traverse this directory structure to generate Unattend.xml.
  - If "HPE - Windows - Unattend - Debug" script is added, the final generated XML is logged in the deployment log, which can be used for debugging. It also checks the XML for valid XML syntax.

### SetupComplete.cmd conventions
 - Scripts created in **/ISdeploy/SetupComplete/** directory are executed by SetupComplete.cmd in alphabetical order (same as order of files listed by "ls" UNIX/Linux command without any options). 
 - SetupComplete.cmd with commands to execute scripts in the above directory is generated by the unmount plan script.
 - A reboot script for Windows is also executed at the end of SetupComplete.cmd which restarts Windows if an empty file exists at "S:\ISdeploy\Restart-required" (/ISdeploy/Restart-required" in Guestfish)  


## References
  - [Unattend.xml components](https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/components-b-unattend)
  

