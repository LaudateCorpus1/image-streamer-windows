# (c) Copyright 2018 Hewlett Packard Enterprise Development LP
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at #http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the License

Try
{

    $SVolume = Get-Volume -DriveLetter S -ErrorAction SilentlyContinue

    if ($SVolume)
    {

        # Remap S to another drive letter
        Get-WmiObject -Class Win32_volume -Filter "DriveLetter = 'S:'" | Set-WmiInstance -Arguments @{DriveLetter='Z:'}

    }

    $CVolume = Get-Partition | ? DriveLetter -eq "C"
    $RootDisk = Get-Disk $CVolume.DiskNumber

    # Take the max size of C and reduce it by 100MB
    $MaxSize = (Get-PartitionSupportedSize -DriveLetter c).sizeMax

    $NewSize = $MaxSize - (100 * 1MB)

    Resize-Partition -DriveLetter c -Size $NewSize

    # Create new partition from the 100 unallocated space, named ISDEPLOY and should be S:
    $NewPartition = New-Partition -DiskNumber $RootDisk.Number -UseMaximumSize -DriveLetter S
    Format-Volume -Partition $NewPartition -FileSystem FAT32 -NewFileSystemLabel ISDEPLOY
    
    reg export HKLM\System\MountedDevices C:\driveletters.reg
    
    # Generalize Windows with sysprep, but quit rather than reboot or shutdown
    & $env:windir\System32\Sysprep\sysprep /generalize /oobe /quit
    
    Wait-Process –Name “sysprep”
    
    reg import C:\driveletters.reg
    
    # Set Windows registry for Image Streamer deployment:
    Set-ItemProperty -Path HKLM:\System\Setup -Name UnattendFile -Value "S:\ISdeploy\Unattend.xml" -Type String

    # Create directory and SetupComplete.cmd
    if (!(test-Path $env:windir\Setup\Scripts))
    {
        New-Item -path $env:windir\Setup\Scripts -ItemType "directory"
    }
    
    "S:\ISdeploy\SetupComplete.cmd" | Out-File $env:windir\Setup\Scripts\SetupComplete.cmd

}

Catch
{

    Throw $_

}
