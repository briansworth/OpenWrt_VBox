<#
.SYNOPSIS
Download OpenWRT and create a VirtualBox VM for running it

.DESCRIPTION
This script will download the provided OpenWRT version and
create a Virtual Box virtual machine using this version of
OpenWRT as the boot disk.
By default, this VM will have 3 network interface cards
  1. Internal network adapter
  2. NAT network adapter
  3. Host-only network adapter
It will have very low specs, 512 MB hdd, 256 MB vRAM, 1 vCPU

.PARAMETER VMName
Name of the virtual machine to create
(default: 'wrt')

.PARAMETER Version
The version of OpenWrt to download and install
(default: '19.07.4')

.PARAMETER VMParentPath
Base VM directory. The directory in which to place the VM folder /
files. A subdirectory named after the VM will be created under
this directory.
(default: '\$HOME/vm')

.EXAMPLE
New-VBoxOpenWrtVM.ps1

This will create the OpenWrt VM using the default values

.EXAMPLE
New-VBoxOpenWrtVM.ps1 -VMName openwrt -Version 19.07.1

This will create the OpenWrt VM with the name 'openwrt' using the
OpenWrt version '19.07.1'

.EXAMPLE
New-VBoxOpenWrtVM.ps1 -VMName openwrt -VMParentPath C:\vm

This will create an the OpenWrt VM with the name 'openwrt' and store
the VM related files under 'C:\vm'
#>
[CmdletBinding()]
Param(
  [Parameter(Position=0)]
  [string]$VMName = 'wrt',

  [Parameter(Position=1)]
  [string]$Version = '19.07.4',

  [Parameter(Position=2)]
  [string]$VMParentPath = (Join-Path -Path $HOME -ChildPath 'vm')
)
Begin
{
  Function Expand-GzipArchive
  {
    [CmdletBinding()]
    Param(
      [Parameter(Position=0, Mandatory=$true)]
      [string]$Path,

      [Parameter(Position=0)]
      [string]$Destination = [string]::Empty
    )
    Try
    {
      $item = Get-Item -Path $Path -ErrorAction Stop
      if ([string]::IsNullOrEmpty($Destination))
      {
        $cwd = (Get-Location).Path
        $Destination = Join-Path -Path $cwd -ChildPath $item.Name
      }
      if (Test-Path -Path $Destination)
      {
        Remove-Item -Path $Destination -ErrorAction Stop
      }

      $fileStream = New-Object -TypeName IO.FileStream -ArgumentList @(
        $item.FullName,
        [IO.FileMode]::Open,
        [IO.FileAccess]::Read,
        [IO.FileShare]::Read
      )
      $writeStream = New-Object -TypeName IO.FileStream -ArgumentList @(
        $Destination,
        [IO.FileMode]::Create,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
      )
      $gzStream = New-Object IO.Compression.GzipStream -ArgumentList @(
        $fileStream,
        [IO.Compression.CompressionMode]::Decompress
      )

      $gzStream.CopyTo($writeStream)
    }
    Catch [Management.Automation.ItemNotFoundException]
    {
      Write-Error -ErrorRecord $_
    }
    Finally
    {
      if ($fileStream)
      {
          $fileStream.Close()
          $fileStream.Dispose()
      }
      if ($writeStream)
      {
          $writeStream.Close()
          $writeStream.Dispose()
      }
      if ($gzStream)
      {
          $gzStream.Close()
          $gzStream.Dispose()
      }
    }
  }
}
Process
{
  # WRT Info
  $imgUri = "$Version/targets/x86/64/openwrt-$Version-x86-64-combined-ext4.img.gz"
  $wrtUrl = "https://downloads.openwrt.org/releases/$imgUri"
  $fileName = "openwrt-$Version.img.gz"

  $downloads = Join-Path -Path $HOME -ChildPath 'Downloads'
  $dlPath = Join-Path -Path $downloads -ChildPath $fileName

  # VM Info
  $vdiSize = '512'
  $vmOsType = 'Linux_64'
  $vmNetName = 'net0'

  $vmPath = Join-Path -Path $VMParentPath -ChildPath $VMName
  $vdiPath = Join-Path -Path $vmPath -ChildPath "$VMName.vdi"

  Try
  {
    # Verify that vboxmanage is an available command
    Invoke-Expression -Command 'vboxmanage --help' -ErrorAction Stop > $null

    # Download OpenWrt IMG file
    Invoke-WebRequest -Uri $wrtUrl `
      -OutFile $dlPath `
      -UseBasicParsing `
      -ErrorAction Stop

    $imgPath = Join-Path -Path $downloads `
      -ChildPath $fileName.Substring(0, $fileName.Length - 3)
    Expand-GzipArchive -Path $dlPath -Destination $imgPath -ErrorAction Stop

    New-Item -Path $vmPath -ItemType Directory -Force -ErrorAction Stop > $null

    # Create OpenWrt VDI file
    vboxmanage convertfromraw --format VDI $imgPath $vdiPath
    vboxmanage modifymedium $vdiPath --resize $vdiSize

    # Create OpenWrt VM
    vboxmanage createvm --name $VMName `
      --ostype $vmOsType `
      --basefolder $VMParentPath `
      --register

    # Attach created VDI
    vboxmanage storagectl $VMName --name 'IDE' --add ide
    vboxmanage storageattach $VMName `
      --storagectl 'IDE' `
      --port 0 `
      --device 0 `
      --type hdd `
      --medium $vdiPath

    # Modify system / general settings
    vboxmanage modifyvm $VMName --cpus 1 --memory 256 --vram 12
    vboxmanage modifyvm $VMName --boot1 disk
    vboxmanage modifyvm $VMName --audio none

    # Add network adapters
    vboxmanage modifyvm $VMName --nic1 intnet --intnet1 $vmNetName
    vboxmanage modifyvm $VMName --nic2 nat
    vboxmanage modifyvm $VMName --nic3 hostonly --hostonlyadapter3 vboxnet0

    vboxmanage showvminfo $VMName | Select-Object -First 20
  }
  Catch [Management.Automation.CommandNotFoundException]
  {
    $emsg = [string]::Format(
      'Command {0} is not accessible in this session {1} {2}',
      'vboxmanage',
      'Add the directory containing this executable to your',
      'PATH variable and try again'
    )
    Write-Error -Message $emsg -Exception $_.Exception
  }
  Catch [Microsoft.PowerShell.Commands.HttpResponseException]
  {
    $emsg = [string]::Format(
      'Failed to download OpenWrt Version: [{0}] Message: {1}',
      $Version.ToString(),
      $_.Exception.Message
    )
    Write-Error -Exception $_.Exception -Message $emsg
  }
}
