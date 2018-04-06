$ConfigFile = "D:\dropbox\config_Lua.xml"
[xml]$Config = Get-Content $ConfigFile
#attendance report
$name = "Sodanickel"
[int]$raidsPerWeek = 2
$DBSub = $Config.settings.baseconfig.workingdir + '\' + $Config.settings.baseconfig.databasefolder + '\'

$global:raidJoinCSV = import-csv ($DBSub + "join.csv") | ?{$_.name -eq "$name"}# -and (get-date $_.date).DayOfWeek } | sort-object -Property date
$global:raidLeaveCSV = import-csv ($DBSub + "leave.csv") | ?{$_.name -eq "$name"} | sort-object -Property date

[datetime]$firstRaid = $raidJoinCSV | select-object -First 1 | select -ExpandProperty date
[datetime]$latestRaid = $raidJoinCSV | select-object -last 1 | select -ExpandProperty date

$totalRaids = ($raidJoinCSV | Select-Object -Property date -Unique).Count
$weeksbetween = ((New-TimeSpan -Start $firstRaid -End $latestRaid | select -ExpandProperty Days) / 7)

$expectedRaids = [math]::Round($weeksbetween * $raidsPerWeek)

"Expected to attend $expectedraids"
"Has attended $totalraids"