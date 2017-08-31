###############################
# TIBCO EMS Queue Status Check
# Author: 
# Last Update: 30/08/2017
# Added ability to detect and switch to primary EMS host
# Changed comparison to depend on total out count
# 
# Usage:
# .\QueueMonitor.ps1
###############################

$monitoredLog = "E:\scripts\EMS_Queue_Monitor\BMC_Alert.txt"
$queueLogs = "E:\scripts\EMS_Queue_Monitor\QueueCountLogs\"
$EMSScript = "E:\scripts\EMS_Queue_Monitor\EMS_Queue_Depth.cmd"
$queueDetailsCMD = "E:\scripts\EMS_Queue_Monitor\QueueDetails.cmd"
$statusScript = "E:\scripts\EMS_Queue_Monitor\EMS_Status.cmd"
$outputFile = "E:\scripts\EMS_Queue_Monitor\EMS_Queues.txt"
$detailedOutputFile = "E:\scripts\EMS_Queue_Monitor\EMS_Queue_Details.txt"
$EMSStatus = "E:\scripts\EMS_Queue_Monitor\EMS_Status.txt"
$EMSPrimary = "tcp://XXXXX:7222"
$EMSSecondary = "tcp://XXXXX:7222"
$prevRunFolder = "E:\scripts\EMS_Queue_Monitor\QueueCount\"
$breachThreshold = 6
$executionFrequency = 5
$EMSQueueDetails = @()
$signifigantQueues = @()
$startTime = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
$time = Get-Date

Remove-Item $queueDetailsCMD
$sendAlert = $false
$alertLog = ""

# Get encrypted password
$encryptedPwd = gc "E:\scripts\EMS_Queue_Monitor\creds.txt" | ConvertTo-SecureString
$encryptedPwd = (New-Object PSCredential "admin",$encryptedPwd).GetNetworkCredential().Password

# Determine active EMS host
$EMSCommand = "E:\tibco\ems\8.2\bin\tibemsadmin -server $EMSPrimary -user admin -password $encryptedPwd -script $statusScript > $EMSStatus"
CMD /C $EMSCommand
$output = gc $EMSStatus
$output = $output[11].Split(' ').Trim() | Where-Object { $_ -ne [String]::Empty }
if($output[1] -eq 'active'){
    "$startTime | INFO | $EMSPrimary detected as primary host." | Out-File $monitoredLog -Append default
    $EMSServer = $EMSPrimary
}else{
    $EMSCommand = "E:\tibco\ems\8.2\bin\tibemsadmin -server $EMSSecondary -user admin -password $encryptedPwd -script $statusScript > $EMSStatus"
    CMD /C $EMSCommand
    $output = gc $EMSStatus
    $output = $output[11].Split(' ').Trim() | Where-Object { $_ -ne [String]::Empty }
    if($output[1] -eq 'active'){
        "$startTime | INFO | $EMSSecondary detected as primary host." | Out-File $monitoredLog -Append default
        $EMSServer = $EMSSecondary
    }else{
        "$startTime | WARNING | Neither EMS Hosts are primary!!" | Out-File $monitoredLog -Append default
    }
}

# Construct command
$EMSCommand = "E:\tibco\ems\8.2\bin\tibemsadmin -server $EMSServer -user admin -password $encryptedPwd -script $EMSScript > $outputFile"

CMD /C $EMSCommand
$prevRun = gci $prevRunFolder

# Get relevant data:
$queueInfo = gc $outputFile
$queues = $queueInfo[13 .. ($queueInfo.Length-2)]

# Build detailed query command
foreach ($queue in $queues){
    $queueName = $queue.Substring(2,53).Replace("$","").Replace("*","").Replace(">","").Trim()
    $queueDepth = $queue.Substring(76,9).Trim()
        
    # Check if queue is > 0
    if([int]$queueDepth -gt 0){
        # Add active queues to multi-dimensional array
        $EMSQueueDetails += , @($queueName,$queueDepth)

        # Add queue to detailed inspection list
        $signifigantQueues += $queueName
        "show stat queue $queueName" | Out-File $queueDetailsCMD -Append default
    }
}
"exit" | Out-File $queueDetailsCMD -Append default

# Get detailed information about all queues with count > 1

$EMSCommand = "E:\tibco\ems\8.2\bin\tibemsadmin -server $EMSServer -user admin -password $encryptedPwd -script $queueDetailsCMD > $detailedOutputFile"
CMD /C $EMSCommand

# Get relevant data:
$queueInfo = gc $detailedOutputFile
$queues = $queueInfo[8 .. ($queueInfo.Length-2)]

# Evaluate every eigth line (Outbound Statistics)
$i=0
for($x=8; $x -le $queues.Count; $x += 9){
    $tempStr = $queues[$x].Split(' ').Trim() | Where-Object { $_ -ne [String]::Empty }
    $EMSQueueDetails[$i] += $tempStr[1]
    $i++
}

foreach($queue in $EMSQueueDetails){
    $breachCount = 1
    
    # Write to Queue History Log
    $logEntry = ([string]$startTime+" | Total Outgoing: "+[string]$queue[2]+" | Message Count: "+[string]$queue[1])
    $logEntry >> ($queueLogs+$queue[0]+".log")
    
    # Check if queue was > 0 last execution
    if($prevRun.name -contains ($queue[0]+".dat")){

        # Get contents of previous check for queue
        $prevQueue = gc ($prevRunFolder+$queue[0]+".dat")

        # Check if queue total outgoing has not increased
        if($queue[2] -le $prevQueue[2]){

#            # Check if queue is stagnant or growing
#            if($prevQueue[0] -le $queueDepth){
#                #Write-Host ("Old Depth:"+$prevQueue[0]+" New Depth:"+$queueDepth)
                
            # Calculate number of breaches
            $breachCount = [int]$prevQueue[1] + 1
#
            # Check if breaches exceed threshold
            if($breachCount -ge $breachThreshold){
#                    
                # Ugly and dirty mute for XXXXXXXXXX before 07:21
                $hour = get-date -format HH
                $minute = get-date -format mm
                if($queue[0] -match "XXXXXXXXXX" -and $hour -le 7 -and $minute -le 21){
                    #Do Nothing
                }else{
                    # Add queue to alert variable
                    #Write-Host ($queueName+" has not reduced "+$breachCount+" times in a row")
                    $sendAlert = $true
                    $alertLog += ($queue[0]+" has been stagnant/increasing for $breachCount consecutive samples. Current queue length is "+$queue[1]+"<br>")
                    foreach($entry in gc -Tail $breachCount ($queueLogs+$queue[0]+".log")){
                        $alertLog += ($entry+"<br>")
                    }
                    
                    #$alertLog += gc -Tail $breachCount ($queueLogs+$queue[0]+".log")
                }
            }
        }
    }

    # Write out .dat files for all queues that were > 0
    $queue[1] > ($prevRunFolder+$queue[0]+".dat")
    $breachCount >> ($prevRunFolder+$queue[0]+".dat")
    $queue[2] >> ($prevRunFolder+$queue[0]+".dat")
}


# Only send alert if a queue has breached alert threshold
if($sendAlert){
    $secureString = New-Object System.Security.SecureString
    $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "NT AUTHORITY\ANONYMOUS LOGON", $secureString
    $body = '<html><body><h2>Tibco EMS Queue Status Check Failure.</h2><br>'+$alertLog+'</body></html>'
    Send-MailMessage -from XXXXXXXXXXX -to XXXXXXXXXX -subject "Tibco EMS Queue Status Check Failure" -body $body -BodyAsHtml -credential $creds -SmtpServer XXXXXXXXXXX
    #Send-MailMessage -from XXXXXXXXXXX -to XXXXXXXXXXX -cc XXXXXXXXXXX -subject "Tibco EMS Queue Status Check Failure" -body $body -BodyAsHtml -credential $creds -SmtpServer XXXXXXXXXXX
    
    "$startTime | WARNING | One or more queues have breached the alert threshold" | Out-File $monitoredLog -Append default
} else {
    "$startTime | INFO | All queues are in a healthy state" | Out-File $monitoredLog -Append default
}

# Remove records older than executionFrequency-2 minutes
$ageLimit = $time.AddMinutes(-$executionFrequency+2)
Get-ChildItem -Path $prevRunFolder | Where-Object { !$_.PSIsContainer -and $_.LastWriteTime -lt $ageLimit } | Remove-Item -Force


# Function for updating perfmon
Function Update-PerfCounter ($EMSQueueDetails){
    $categoryName = "Tibco EMS Queue Depth Custom PerfCounters"
    $categoryHelp = "Custom Performance Counters for TIBCO EMS"
    $categoryType = [System.Diagnostics.PerformanceCounterCategoryType]::SingleInstance
    $categoryExists = [System.Diagnostics.PerformanceCounterCategory]::Exists($categoryName)

    If (-Not $categoryExists){
        write-host hello
        # Perfmon DataCollection
        $objCCDC = New-Object System.Diagnostics.CounterCreationDataCollection

        # Individual Perfmon Counters
        foreach ($EMSQueue in $EMSQueueDetails){
            
            if ($EMSQueue[0] -match " "){
                # Stupid typos!!!!
            }else{
                $objCCD = New-Object System.Diagnostics.CounterCreationData
                $objCCD.CounterName = $EMSQueue[0]
                $objCCD.CounterType = "NumberOfItems32"
                $objCCD.CounterHelp = "Tibco EMS Queue Depth"
                $objCCDC.Add($objCCD) | Out-Null
            }
        }
        
        #Write-Host $objCCDC

        # Create Perfmon Collection+Counters
        [System.Diagnostics.PerformanceCounterCategory]::Create($categoryName, $categoryHelp, $categoryType, $objCCDC) # | Out-Null
    }

    # Update values of Perfmon Counters
    foreach ($EMSQueue in $EMSQueueDetails){
        
        $perfMonStatus = New-Object System.Diagnostics.PerformanceCounter($categoryName, $EMSQueue[0], $false)
        $perfMonStatus.RawValue = $EMSQueue[1]
        #$perfMonStatus.RawValue = Get-Random(1..20)

        #if ($EMSQueue[1] > 0){
        #    Write-Host $EMSQueue[0]
        #    Write-Host $EMSQueue[1]
        #}
    }
}

# Pass this var to perfmon function
Update-PerfCounter $EMSQueueDetails

# Use this to delete perfmon counters
#[System.Diagnostics.PerformanceCounterCategory]::Delete("Tibco EMS Queue Depth Custom PerfCounters")  | Out-Null
