###################################################################################################
## SWIFT Event Journal Monitor
## Author: Jasper
## Last Update: 31/05/2017
##
## Description:
## Script to generate and process SWIFT event logs post automated STOP/START to confirm success.
## Calls saa_system readlog to retrieve SWIFT events for a specific time period.
## Processes these messages and evaluates whether the specified action was successful.
## Outputs to a log that is monitored.
##
## Usage Examples:
## SAA_Monitor.ps1 -action SWIFT_Start
## SAA_Monitor.ps1 -action SWIFT_Stop
## SAA_Monitor.ps1 -action SWIFT_Backup
## SAA_Monitor.ps1 -action SWIFT_Emission_Start
## SAA_Monitor.ps1 -action SWIFT_Reception_Start
## SAA_Monitor.ps1 -action SWIFT_FIN_Start
## SAA_Monitor.ps1 -action SWIFT_FIN_Start_Secondary
##
## Not Yet Implemented:
## SAA_Monitor.ps1 -action TIBCO_SOAP_Connect
###################################################################################################

# Get Action
Param(
    [string]$action = "NOT SPECIFIED"
    #[string]$action = "SWIFT_Start"
)

# Initialise Variables
$today = get-date -Format yyyyMMdd
$dayOfWeek = (get-date).DayOfWeek.value__
$swiftLogPath = 'E:\scripts\SAA_Monitor\'
$swiftLogFile = ($today+"_"+$action+".txt")
$monitorLog = ($swiftLogPath+$today+"_SWIFT_Journal_Monitor.txt")
$commandRoot = "E:\Access\bin\saa_system"
$maxRetrieved = 300
$checkLog = ""
$logEntryObj = New-Object System.Object
$notFirst = $false
$passedTest = $true
$alertThreshold = 0
$missingMessages = @()
$logArray = @()
$alerts = @()

# Function for writing to log file
function writeLog ($classification,$message){
    $time = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    "$time | $classification | $message" | Out-File $monitorLog -Append default
}

# Exit if no action is specified
if ($action -eq "NOT SPECIFIED"){
    writeLog "ALERT" "The SWIFT check has been initiated without specifying an action."
    exit 1
} else {
    writeLog "INFO" "The SWIFT check for the '$action' action is beginning."
}

# Set verification messages and time window based on which action is specified.
switch ($action) 
    { 
        "SWIFT_Start" {
            $fromMonFri = "04:00:00"
            $toMonFri = "04:05:00"
            $fromSatSun = "06:00:00"
            $toSatSun = "06:05:00"
            $alertThreshold = 1
            $verificationMessages = @(
                'Component WSS has started. No action required.',
                'Component SNIS has started. No action required.',
                'Component SIS has started. No action required.',
                'Component MXS has started. No action required.',
                'Component SNSS has started. No action required.',
                'Component SAXS has started. No action required.',
                'Component RMS has started. No action required.',
                'Component TRS has started. No action required.',
                'Component MAS has started. No action required.',
                'Component SSS has started. No action required.',
                'SWIFTAlliance servers have started in Operational mode.',
                'Component BSS has started. No action required.',
                'Component XSS has started. No action required.',
                'Component SSA has started. No action required.',
                'Component RMA has started. No action required.',
                'Component MPA has started. No action required.',
                'SWIFTAlliance RPC servers listening on the following IP address(es):',
                'Alliance system has entered RUNNING status, reason is: BS_csys initialisation ha',
                'Database Recovery is Activated.'
                )
            }
        "SWIFT_Stop" {
            $fromMonFri = "23:55:00"
            $toMonFri = "23:59:55"
            $fromSatSun = "15:00:00"
            $toSatSun = "15:05:00"
            $verificationMessages = @(
                'Component SSS has stopped. No action required.',
                'Component SNSS has stopped. No action required.',
                'Component SNIS has stopped. No action required.',
                'Component MXS has stopped. No action required.',
                'Component RMS has stopped. No action required.',
                'Component SIS has stopped. No action required.',
                'Component SAXS has stopped. No action required.',
                'Component WSS has stopped. No action required.',
                'Component MAS has stopped. No action required.',
                'Component TRS has stopped. No action required.',
                'Component XSS has stopped. No action required.',
                'Component SSA has stopped. No action required.',
                'Component RMA has stopped. No action required.',
                'Component MPA has stopped. No action required.'
                )
            } 
        "SWIFT_Backup" {
            $fromMonFri = "23:39:00"
            $toMonFri = "23:44:00"
            $fromSatSun = "14:39:00"
            $toSatSun = "14:44:00"
            $verificationMessages = @(
                'Backup Database ended successfully in server location : E:\Access\backu',
                'Removal of previous Database Backup successful : E:\Access\backup\db',
                'Backup Database started in server location : E:\Access\backup\db'
                )
            }
        "SWIFT_Emission_Start" {
            $fromMonFri = "06:44:00"
            $toMonFri = "06:46:00"
            $fromSatSun = "06:44:00"
            $toSatSun = "06:46:00"
            $verificationMessages = @(
                'Emission profile XXXX activated on connection',
                'Emission profile YYYY activated on connection'
                )
            }
        "SWIFT_Reception_Start" {
            $fromMonFri = "06:39:00"
            $toMonFri = "06:41:00"
            $fromSatSun = "06:39:00"
            $toSatSun = "06:41:00"
            $verificationMessages = @(
                'Reception profile XXXX activated on connection',
                'Reception profile YYYY activated on connection'
                )
            }
        "SWIFT_FIN_Start" {
            $alertThreshold = 1
            $fromMonFri = "04:30:00"
            $toMonFri = "04:32:00"
            if ($dayOfWeek -eq 0){
                # If Sunday
                $fromSatSun = "08:30:00"
                $toSatSun = "08:32:00"                
            } elseif ($dayOfWeek -eq 6){
                # If Saturday
                $fromSatSun = "06:30:00"
                $toSatSun = "06:32:00"
                }
            $verificationMessages = @(
                'LT XXXX: Select ACK received:',
                'LT XXXX: Automatic Select sent:',
                'LT XXXX: Login ACK received:',
                'LT XXXX: Automatic Login sent:',
                'LT XXXX: SL Open Confirm received from the session layer. Local Reference:',
                'LT XXXX: SL Open Request sent to first connection'
                )
            }
        "SWIFT_FIN_Start_Secondary" {
            $fromMonFri = "08:59:00"
            $toMonFri = "09:01:00"
            if ($dayOfWeek -in 0,6){
                # This check should never occur on Sat/Sun
                writeLog "ALERT" "The SWIFT_FIN_Start_Secondary check has been initiated on an invalid date."
                exit 1
            }
            $verificationMessages = @(
                'LT XXXX: Select ACK received:',
                'LT XXXX: Automatic Select sent:',
                'LT XXXX: Login ACK received:',
                'LT XXXX: Automatic Login sent:',
                'LT XXXX: SL Open Confirm received from the session layer. Local Reference:',
                'LT XXXX: SL Open Request sent to first connection'
                )
            }
#        "TIBCO_SOAP_Connect" {
#            writeLog "ALERT" "The TIBCO_SOAP_Connect check is not yet implemented."
#            exit 1
#            $fromMonFri = "23:55:00"
#            $toMonFri = "23:59:00"
#            $fromSatSun = "15:00:00"
#            $toSatSun = "15:05:00"
#            $verificationMessages = @(
#                'UNDEFINED',
#                'UNDEFINED',
#                'UNDEFINED',
#                'UNDEFINED'
#                )
#            }
        default {
            writeLog "ALERT" "The SWIFT check has been initiated with an invalid action."
            exit 1
        }
    }

# Check what day of the week it is and build the command appropriately.
if ($dayOfWeek -in 1..5){
    # Monday - Friday
    $command = "$commandRoot readlog $swiftLogPath$swiftLogFile -startdate $today -startime $fromMonFri -stopdate $today -stoptime $toMonFri -records $maxRetrieved"
}else{
    # Saturday - Sunday
    $command = "$commandRoot readlog $swiftLogPath$swiftLogFile -startdate $today -startime $fromSatSun -stopdate $today -stoptime $toSatSun -records $maxRetrieved"
}

# Execute the 'saa_system readlog' command
CMD /C $command

# Retrieve Event Log
if (!(Test-Path ($swiftLogPath+$swiftLogFile))){
    writeLog "ALERT" ($swiftLogPath+$swiftLogFile+" does not exist! Execution of saa_system must have failed.")
    exit 1
}
else{
    $swiftLog = Get-Content ($swiftLogPath+$swiftLogFile)
}

# Convert log into Array of Objects
foreach ($line in $swiftLog){
    # Check if proccessed line is beginning of new record
    if ($line -match "Reverse date time"){
        # Add $logEntryObj to $logArray unless start of file
        if($notFirst){
            $logArray += $logEntryObj
        }
        # Re-Initialise $logEntryObj
        $logEntryObj = New-Object System.Object
        # Change flag indicating no longer processing first line
        $notFirst = $true
    }
    # Split line at the = and add (attribute : value) to $logEntryObj
    $line = $line.Split("=")
    if($line[0] -ne $null -and $line[1] -ne $null){
        $logEntryObj | Add-Member -type NoteProperty -Name $line[0].Trim() -Value $line[1].Trim()
    }
}

# Confirm that all $verificationMessages are represented within the retrieved log
$visibleLog = $logArray | select -Property 'Display Text'
foreach ($message in $verificationMessages){
    $found = $false
    foreach ($log in $visibleLog){
        if ($log.'Display text'.Contains($message)){
            $found = $true
            break
        }
    }
    if ($found -eq $false){
        $passedTest = $false
        $missingMessages += $message
    }
}

# Write messages to the log depending on the result of the previous test.
if($passedTest){
    writeLog "INFO" ("All expected event entries were found.")
}else{
    writeLog "ALERT" ("The following messages were not found:")
    foreach($message in $missingMessages){
        writeLog "MISSING" $message
    }
}

# Retrieve all events with severity > Info and alert if this count breaches $alertThreshold
$alerts += $logArray | Where-Object {$_.'Event severity' -ne 'Info'}
if ($alerts.Count -gt $alertThreshold){
    writeLog "ALERT" ([string]$alerts.Count+" message(s) that are of 'Warning' or higher severity have been detected. The alert threshold for '$action' is $alertThreshold.")
    foreach($message in $alerts){
        writeLog "ALERT" $message.'Display text'
    }
}
writeLog "INFO" "The SWIFT check for the '$action' action has completed."

# Remove log files older than 8 days
$time = Get-Date
$ageLimit = $time.AddDays(-8)
Get-ChildItem -Path $swiftLogPath -File *_SWIFT_*.txt | Where-Object { !$_.PSIsContainer -and $_.LastWriteTime -lt $ageLimit } | Remove-Item -Force
