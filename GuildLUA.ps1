PARAM(
    [switch]$db,
    [string]$character,
    [string]$raid,
    [string]$lastloot,
    [string]$itemsearch,
    [string]$filename,
    [int]$quantity
)
$ConfigFile = "H:\GuildLUA\coddddnfig_Lua.xml"



<#
KNOWN BUGS/NEEDS IMPLEMENTATION
GUILDLUA.PS1

Version number + update checker (NuGet)
Build attendance tracker. Calculate raid days based on times > Allow linkage between 1 Main > Many alt
Add help data
Filter based on Time as well as date (partially implemented)
Implement functionality for raids that span over night (Past midnight)


GUI STUFF
CONFIGGUI.PS1

Configuration GUI    : Change LUA file to WoW folder selection box
                     : Tickbox (Only report raid days and times)
                     : TIME CONFIG : Enable tickbox for convert to server time
                     : ID LOOKUP PREFIX
                     : Help section - Explanation of Working Directory
                     : Even out spacing between the options - Misaligned
                     : add trigger for report raid times only - needs to grey out all unneeded boxes



MAINGUI.PS1
Reporting GUI        : Character search (Accompanying text indicating * option)
                     : Raid Search (Accompanying text indicating * option)
                     : Item Search (Accompanying text indicating * option)
                     : Last Loot (Accompanying text indicating * option)
                     : Generate DB (Single filename selection option)
                     : Help
                     : Introduction
#>
$ErrorActionPreference = "stop"

#Making sure an appropriate version of powershell is installed
if ($PSVersionTable.psversion.major -le "4") { 
    'ERROR: Your version of Powershell is out of date and is incompatible with this script.'
    'Please visit https://www.microsoft.com/en-us/download/details.aspx?id=54616 and install Windows Management Framework Version 5 or higher in order to proceed'
    exit 
}

#Configuration file logic.
#First, A static entry can be configured in the "ConfigFile" variable
#If this cannot be located, We look in the current working directory for the file. If this can't be found, the script stops.
$currentDir = Get-Location | select-object -ExpandProperty path
$localConf = $currentdir + '\' + 'config_lua.xml'
$localStamp = $currentdir + '\' + 'stamp.txt'
if (!(test-path $configfile -ErrorAction SilentlyContinue)) {
    try {
        if (test-path -ErrorAction SilentlyContinue $localConf) { 
            "Using configuration file $localconf"
            $ConfigFile = $localConf
            if (test-path $localStamp) { 
                if ((get-content $localstamp) -eq '19685a9d1dc9ae0cc97c49c95419cb48b0993f14') {
                    [xml]$Config = Get-Content $ConfigFile
                    if ($Config.settings.baseconfig.workingdir -ne $currentdir) {
                        'Updating the settings to use the current directory as the new working directory'
                        $config.settings.baseconfig.workingdir = $currentDir.ToString()
                        $config.save($ConfigFile)
                    }
                }
            }
        }
    }
    catch { $error[0] } 
}


#Variable declaration
#Pre-Requisite checks for existing data. Creates directories if they do not exist
$DBSub = $Config.settings.baseconfig.workingdir + '\' + $Config.settings.baseconfig.databasefolder + '\'
$RPSub = $Config.settings.baseconfig.workingdir + '\' + $Config.settings.reporting.reportfolder + '\'
$CharacterReportFolder = $RPSub + 'Character\'
$RaidReportFolder = $RPSub + 'Raids\'
if ((test-path $Config.settings.baseconfig.workingdir) -eq $false) { mkdir $Config.settings.baseconfig.workingdir }
if ((test-path $DBSub) -eq $false) { mkdir $DBSub }
if ((test-path $RPSub) -eq $false) { mkdir $RPSub }
$IDLookupPrefix = 'https://classicdb.ch/?item=' #Used in loot output, PREFIX + ITEMID = URL
$joinfile = $dbsub + 'join.csv'
$leavefile = $dbsub + 'leave.csv'
$lootfile = $dbsub + 'loot.csv'
$files = $joinfile, $leavefile, $lootfile


#Reloading config file in case it was not loaded properly above.
[xml]$Config = Get-Content $ConfigFile

if (test-path ($Dbsub + 'blacklist.txt')) { $blacklist = get-content ($DBsub + 'blacklist.txt') }
#Function declaration

#Generate an array full of the loot listings for quicker searching
function genLootArray {
    $script:lootarray = import-csv ($DBSub + '\' + 'loot.csv')
}
function Update-ConfigFile($property, $value) {
    $config.settings. + $property = $value
}
function RaidFunction {
    $raidDays = $Config.settings.reporting.Raiddays.Split(",") 
    $raidStart = $config.settings.reporting.monitoredtimestart
    $raidDuration = $config.settings.reporting.monitoredDuration
    Write-host "Generating raid specific reports. Please wait"
    $collection = New-Object System.Collections.ArrayList
    $rjoinCSVimport = import-csv $joinfile
    $rleaveCSVimport = import-csv $leavefile
    $rlootCSVimport = import-csv $lootfile   
    $RaidReportFolder = $RPSub + 'Raids\'
    if ((test-path $RaidReportFolder) -ne $true) { mkdir $RaidReportFolder }
    if ($raid -eq '*') {
        $filelist = $files | Foreach-Object { 
            $import = import-csv $_ 
            foreach ($item in $import) { 
                switch ($item.mode) {
                    leave { $time = $item.leave }
                    join { $time = $item.join }
                    loot { $time = $item.loot }
                }
                [datetime]$dateformatting = $item.date.Replace('.', '/') ; $time
                if (($Raiddays -like $dateformatting.dayofweek) -and ($Config.settings.reporting.raidtimeonly -eq $true) -and ($blacklist -notcontains $item.date)) { 
                    $item.date
                }
                if (($Config.settings.reporting.raidtimeonly -ne $true) -and ($blacklist -notcontains $item.date)) {  $item.date }
            }
        }
        $collection = $filelist | select-object -unique
    }
    else { $collection = $raid }
        
    #Ok, Now we've determined the results we're looking for. Lets start the processing.
    foreach ($raidentry in $collection) {
        #Output File Name
        $raidreportfilename = $raidreportfolder + 'RaidReport_' + $raidentry + '.csv'
        #Go through Join.csv, Find all entries, Parse through unique
        #Add Leave.CSV, Find all entries, Filter unique in addition to join (Just in case someone joined while you were DC'd)
        #Filter all results, Find last leave and last join for that user in a loop
        #Repeat for loot, Semicolon separate all loot items
        #Add URL for loot items
    
        $namearray = New-Object System.Collections.ArrayList($null)
        $sortJoins = $rjoinCSVimport | Where-Object {$_.date -eq $raidentry}
        $sortLeaves = $rleaveCSVimport | Where-Object {$_.date -eq $raidentry}
        $sortLoot = $rlootCSVimport | Where-Object {$_.date -eq $raidentry}
    
                
        $sortjoins | Foreach-Object { [void]$namearray.Add($_.name) }
        $sortleaves | Foreach-Object { [void]$namearray.Add($_.name) }
        $sortloot | Foreach-Object { [void]$namearray.Add($_.name) }
            
        $namearray = $namearray | Select-Object -Unique
       
        $store = foreach ($name in $namearray) { 
            $lootlist = $null
            $JoinTime = $sortjoins | Where-Object {$_.name -eq "$name"} | sort-object -Property join | select-Object join -first 1
            $leavetime = $sortleaves | Where-Object {$_.name -eq "$name"} | sort-object -property leave | select-Object leave -last 1
            $lootCollection = $sortloot | Where-Object {$_.name -eq "$name"} | Where-Object {$_.priority -ge $Config.settings.reporting.qualityfilter}
            foreach ($loot in $lootcollection) {
                if ($lootlist -eq $null) { $lootlist = $loot.item } else { $lootlist = $lootlist + ";" + $loot.item }
                if ($URLlist -eq $null) { $URLlist = $loot.URL } else { $URLlist = $URLlist + ";" + $loot.URL }
            }
            if (!$leavetime.leave) { $perPersonLeave = "NO DATA" } else { $perPersonLeave = $leavetime.leave }
            if (!$jointime.join) { $perPersonjoin = "NO DATA" }  Else { $perPersonJoin = $jointime.join }
            $obj = [pscustomobject][ordered]@{
                Name  = $name
                Join  = $perPersonJoin
                Leave = $perPersonLeave
                Loot  = $lootlist
                URL   = $URLList
            
            }
            $obj
            $lootlist = $null
            $urllist = $null
        }
        $store | export-csv $raidreportfilename -NoTypeInformation
    }
}


#Function to search characters in DB
function characterSearch($charname) {
    if (!(test-path $CharacterReportFolder)) { mkdir $CharacterReportFolder }
    if (!$lootarray) {
        genLootArray
    }
    $comma = ','
    #Multiple character search using comma separation
    if ($charname -match $comma) { 
        $characterList = $character.split(',')
        foreach ($C in $characterList) {
            characterSearch -charname $C
        }
    
    }

    #All character search
    if ($charname -eq '*') {
        "Generating character reports for all users in the database. This may take some time."
        $chararray = New-Object System.Collections.ArrayList($null)
        $lootarray = $LootArray | Where-Object {$blacklist -notcontains $_.date} | sort-object -Property Name
        foreach ($entry in $lootarray) {
            if (($entry.name -ne $lastname) -and ($lastname -ne $null)) {
                $CharacterReport = $CharacterReportFolder + $lastname + "_loot.csv"
                $charArray | Select-Object * -ExcludeProperty Mode | export-csv $CharacterReport -NoTypeInformation
                $chararray = New-Object System.Collections.ArrayList($null)
            }
            if ($entry.priority -ge $config.settings.reporting.qualityfilter) { [void]$charArray.Add($entry) }
            $lastname = $entry.name
        }
    }


    #Single character search
    if (($charname -notlike "*,*") -and ($charname -ne '*')) {
        $CharacterReport = $CharacterReportFolder + $charname + "_loot.csv"
        $filteredLootArray = $LootArray | Where-Object {$_.name -eq $Charname -and $blacklist -notcontains $_.date}
        $characterStore = foreach ($loot in $filteredLootArray) {
            if ($loot.priority -ge $Config.settings.reporting.qualityfilter) { $loot }
        }
        $characterstore | export-csv $characterreport -notypeinformation
    }
}



#Function for logging
function Write-Log {
    $currenttime = get-date -Format "[yyyy-MM-dd] H:mm:ss"
    $string = $currenttime + " " + $args
    $string | out-file $Config.settings.baseconfig.logfile -append
    write-host $string
}

Function GenDB {

    #Declaring objs for holding the data
    $store = @{}

    #Generating database begins
    
    if ($config.settings.baseconfig.Freshrun -eq $true) { "Database generation being performed in FRESH mode"}
    else { "Database generation being performed in APPEND mode."}

    #Beginning loop through files
    $store = foreach ($DBFile in $DBFilesList) {
        $import = Get-Content $Dbfile
        foreach ($entry in $import) { 
            $obj = @()
            $int++ #Counter

            #Determining which block we are processing. Leave, Loot or Join
            if ($entry -eq '		["Leave"] = {') { $mode = "leave"}
            if ($entry -eq '		["Join"] = {') { $mode = "join" }
            if ($entry -eq '		["Loot"] = {') { $mode = "loot" }



            #Parsing individual results
            $Raw = $entry.Split('=')
            $CurrentItem = $Raw[0]
            $Value = $raw[1]
            $value = $value -replace '"', ""
            $value = $value -replace ',', ""


            #Player object begin
            if ($CurrentItem -match [Regex]::Escape($Player)) { 
                $currentPlayer = $raw[1]
                $currentplayer = $currentplayer.Replace('"', '') #Trimming quotation marks
                $currentplayer = $currentplayer.Replace(',', '') #Trimming commas
                $currentplayer = $currentplayer.Trim()           #Trimming whitespace
            }
            #URL processing
            if ($CurrentItem -match [Regex]::Escape($ID)) { 
    
                $URL = $IDLookupPrefix + "$value"
                $url = $url.Replace(" ", "") 
                $Url = $url.Split(':')
                $url = $url[0] + ':' + $url[1]
                #$url
            }

            #Quantity processing
            if ($CurrentItem -match [Regex]::Escape($count)) {  $quantity = $value } #$CurrentItem }

            #Name of items
            if ($CurrentItem -match [Regex]::Escape($name)) { $itemName = $value } #$CurrentItem }

            #Color processing
            if ($CurrentItem -match [Regex]::Escape($colorhex)) {
                $colorvalue = $value.Trim()
                if ($colorvalue -eq "ff9d9d9d") { $coloringame = "Grey" ; $colorpriority = "0"}
                if ($colorvalue -eq "ffffffff") { $coloringame = "White" ; $colorpriority = "1"}
                if ($colorvalue -eq "ff1eff00") { $coloringame = "Green" ; $colorpriority = "2"}
                if ($colorvalue -eq "ff0070dd") { $coloringame = "Blue" ; $colorpriority = "3"}
                if ($colorvalue -eq "ffa335ee") { $coloringame = "Epic" ; $colorpriority = "4" }
                if ($colorvalue -eq "ffff8000") { $coloringame = "Legendary" ; $colorpriority = "5" }
            }


            #Time processing
            if ($CurrentItem -match [Regex]::Escape($time)) {
                if (!$mode) { write-log "Error. Mode unknown on line" $int ; break }

                #Gathering date and time information
                $RawDate = $value -split "\s+"

                #Converting the raw data into a Powershell DATETIME object.
                [datetime]$date = $Rawdate[1] + " " + $rawdate[2]

                #The dates are stored in US format, So let's make sure thats taken into consideration before we start changing things.
                $USFormat = get-date $Date -format ($US.DateTimeFormat.FullDateTimePattern) 
                if ($config.settings.reporting.convServerTime -eq $true) {
                    $ConvertedDate = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($USFormat, [System.TimeZoneInfo]::Local.Id, $Config.settings.baseconfig.timezoneid)
                    $datestamp = get-date $ConvertedDate -format "yyyy.MM.dd"
                    $Timestamp = get-date $ConvertedDate -Format "HH:mm:ss"
                }
        
                else {
                    $datestamp = get-date $USFormat -format "yyyy.MM.dd"
                    $Timestamp = get-date $USformat -Format "HH:mm:ss"
                }
        
            }
            #Conversion finished, Lets now store the date and time in individual variables for ease of access.
    
            #Final block - Write the objects out
            if ($CurrentItem -match [Regex]::Escape($final) -and ($currentitem.length -eq $final.length)) {
                if ($mode -eq "leave") { 
                    $obj = [pscustomobject][ordered]@{
                        Name  = $currentplayer
                        Leave = $timestamp
                        Date  = $datestamp
                        Mode  = $mode
                    }
                    #Passing object to the pipeline to store in $store
                    $obj
                    #Blanking to ensure that data is fresh each loop
                    $obj = $null
                    $currentplayer = $null
                    $timestamp = $null
                }

                if ($mode -eq "join") {
                    $obj = [pscustomobject][ordered]@{
                        Name = $currentplayer
                        Join = $timestamp
                        Date = $datestamp
                        Mode = $mode
                    }
                    #Passing object to the pipeline to store in $store
                    $obj
                    #Blanking to ensure that data is fresh each loop
                    $obj = $null
                    $currentplayer = $null
                    $timestamp = $null
                }

                if ($mode -eq "loot") {
                    $obj = [pscustomobject][ordered]@{
                        Name     = $currentplayer
                        Item     = $itemName.SubString(1)
                        Color    = $colorvalue
                        Quantity = $quantity
                        Quality  = $coloringame
                        Priority = $colorpriority
                        URL      = $URL
                        Date     = $datestamp 
                        Mode     = $mode
                        Loot     = $timestamp
                    }
                    #Passing object to the pipeline to store in $store
                    $obj
                    #Blanking to ensure that data is fresh each loop
                    $obj = $null
                    $currentplayer = $null
                    $itemName = $null
                    $colorvalue = $null
                    $quantity = $null
                    $coloringame = $null
                    $colorpriority = $null
                }
            }
        }

    }
    $joinexportfile = $DBSub + 'join.csv'
    $leaveexportfile = $DBSub + 'leave.csv'
    $lootexportfile = $DBSub + 'loot.csv'
    $joinArr = New-Object System.Collections.ArrayList($null)
    $leaveArr = New-Object System.Collections.ArrayList($null)
    $lootArr = New-Object System.Collections.ArrayList($null)
    foreach ($entry in $store) { 
        switch ($entry.mode) {
            join {[void]$joinArr.Add($entry) }
            leave {[void]$leaveArr.Add($entry)}
            loot {[void]$lootArr.Add($entry)}
        }
    }
    #checking for existence of database files, fresh run mode is assumed if no CSV files in DB folder
    $LS = Get-ChildItem ($dbsub + '\' + "*.csv") | Where-Object {$_.name -eq "join.csv" -or $_.name -eq "leave.csv" -or $_.name -eq "loot.csv"}
    if (($config.settings.baseconfig.dbfreshrun -eq "True") -or (!$LS)) {
        $lootarr | export-csv $lootexportfile -NoTypeInformation
        $joinarr | export-csv $joinexportfile -NoTypeInformation
        $leavearr | export-csv $leaveexportfile -NoTypeInformation
        #Making sure we refresh the loot array after a database refresh
    }
    else {
        $oldLootarr = import-csv $lootexportfile
        $oldjoinarr = import-csv $joinexportfile
        $oldleavearr = import-csv $leaveexportfile

        $diffLoot = compare-object -ReferenceObject $oldLootArr -DifferenceObject $lootarr 
        $diffjoin = compare-object -ReferenceObject $oldjoinArr -DifferenceObject $joinarr 
        $diffLeave = compare-object -ReferenceObject $oldleaveArr -DifferenceObject $leavearr 

        if ($diffLoot.InputObject) { 
            $count = $diffloot.inputobject.count
            "Found $count entries to be added to the loot database."
            $diffloot.inputobject | ForEach-Object { [void]$lootarr.Add($_) ; $lootarr | export-csv $lootexportfile -NoTypeInformation }
        } 
        else { "No differences found in loot entries. Skipping this"}


        if ($diffLeave.InputObject) { 
            $count = $diffleave.inputobject.count
            "Found $count entries to be added to the leave database."
            $diffleave.inputobject | ForEach-Object { [void]$leavearr.Add($_) ; $leavearr | export-csv $leaveexportfile -NoTypeInformation }
        } 
        else { "No differences found in leave entries. Skipping this"}

        if ($diffjoin.InputObject) { 
            $count = $diffjoin.inputobject.count
            "Found $count entries to be added to the join database."
            $diffjoin.inputobject | ForEach-Object { [void]$joinarr.Add($_) ; $joinarr | export-csv $joinexportfile -NoTypeInformation }
        } 
        else { "No differences found in join entries. Skipping this"}
    }
    if ($lootarray) { genlootarray }
    write-host "Database generation complete."
}

#END FUNCTION DECLARATION

#END CONFIGURABLE SECTION



$US = New-Object system.globalization.cultureinfo("en-US") #Times are saved in US format in the LUA file. This variable helps us convert that





#START DATABASE GENERATION OF LUA TO CSV

if ($DB) {
    #Finding which files are to be used. If no -filename parameter, Search the WoW directory.
    if (!$Filename) { 
        "No filename specified. Searching WoW directory for suitable files"
        $WTFAccount = "\WTF\ACCOUNT\"
        try { $DBFilesList = Get-Childitem ($config.settings.baseconfig.wowfolder + $WTFAccount + '\*\SavedVariables\CT_Raidtracker.lua') }
        catch { throw "Error: No files found. Check the wow folder location in the config and try again" ; exit }
        "Scanning through LUA file(s) for CT_RaidTracker information, This may take a few minutes..."
        $count = $dbfileslist.count ; "Found $count files"
    }
    else {
        #Sanity check for existence of filename
        $fullpathfilename = (Get-Location).path + '\' + $filename
        if ((test-path $filename) -eq $false) { $Check1 = $false } else { $DBFilesList = Get-ChildItem $filename }
        if ((test-path $fullpathfilename) -eq $false) { $check2 = $false } else { $DBFilesList = Get-ChildItem $fullpathfilename }
        if (($check1 -eq $false) -and ($check2 -eq $false)) {  write-host "ERROR: NO FILE FOUND BY THE NAME OF $filename" ; exit } 
        #
    }
    #Declaring object types
    $player = '				["player"]'
    $time = '				["time"]'
    $name = '					["name"]'
    $colorhex = '					["c"]'
    $count = '					["count"]'
    $ID = '					["id"]'
    $final = '			},'

    #Freshrun - Make sure we operate with a clean database.
    if ($config.settings.baseconfig.dbfreshrun -eq "True") { 
        "Freshrun mode selected, Deleting old database files"
        #This deletes information about ALL previous runs. Set $config.settings.baseconfig.dbfreshrun to $false if you do not want this to occur
       foreach ($file in $files) {
        if (test-path $file) { Remove-Item $file }
       }
    }
    $mode = $null
    [int]$int = 0


    #Calling GenDB Function
    GenDB
} 
#END GENERATION OF DB FUNCTION

if ($raid) {
    raidfunction

}

#Character search

#Looking for -Character flag.
if ($Character) {
    charactersearch -charname "$character"
}


 


if ($itemsearch) {
    if (!$lootarray) { genlootarray }
    foreach ($entry in $lootarray) {
        if ($entry.item -like $itemsearch) { $entry }
    }
}

#Use name expressions to make multiple columns for output 

<#IE
Zaldre      Zombius
Item1       Item3  
Item2       Item4
#>
if ($lastloot) {
if (!$lootarray) { genlootarray ; $Lootarray = $lootarray | sort-object -Property date }
    if ($lastloot -like "*,*") { "Multiple characters found"; $looter = $lastloot.Split(",")}
    else {$Looter = $lastloot }
    foreach ($entry in $looter) { 
        $lootarray | Where-Object {$_.name -eq $entry} | Select-Object Item -Last 5
    }
}
