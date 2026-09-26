# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

param([Parameter(Mandatory)][string]$Serial)
# Print the COM port of the Espressif native-USB board whose USB serial (its MAC) is
# $Serial; exit 1 if it is not present. A file, not an inline -Command: the inline
# version returned nothing for a board that was plainly on COM11.
$parent = "USB\VID_303A&PID_1001\$Serial"
$dev = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -eq $parent }
if (-not $dev) { exit 1 }
$ports = Get-PnpDevice -PresentOnly -Class Ports | Where-Object { $_.FriendlyName -match '\((COM\d+)\)' }
foreach ($p in $ports) {
    $par = (Get-PnpDeviceProperty -InstanceId $p.InstanceId -KeyName DEVPKEY_Device_Parent).Data
    if ($par -eq $parent -and $p.FriendlyName -match '\((COM\d+)\)') { $Matches[1]; exit 0 }
}
exit 1
