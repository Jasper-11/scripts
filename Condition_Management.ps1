###############################
# Control-M Condition Management Script
#
# This script will generate a list of all conditions that can't possibly be satisfied on the AJF
# The script will then post any of these if they commence with '#' as these are maybe conditions.
# The script will then email out a list of all the remaining 'manual' conditions that can't possibly be satisfied on the AJF.
#
# Author: Jasper
# 
# Usage:
# .\Condition_Management.ps1
###############################

$logDir = 'E:\scripts\ConditionManagement\'
$ctmBinDir = "E:\Control-M Server\ctm_server\exe\"
$date = Get-Date -Format 'yyyyMMdd'

# Declare manual conditions array
$manualConds = @()

# Change working directory to CTM Utilities folder
cd $ctmBinDir

# Execute ctmldnrs to list out all manual and maybe conditions
$cmd = "ctmldnrs -CALCCOND -ADDMODE NO -OUTPUT "+ $logDir + "Maybe_Conditions.txt"
iex $cmd

# Execute ctmldnrs to load all maybe conditions
$cmd = "ctmldnrs -LOAD '#*' -INPUT "+ $logDir + "Maybe_Conditions.txt > " + $logDir + $date + "_Maybe_Conditions.txt"
iex $cmd
cat ($logDir + $date + "_Maybe_Conditions.txt")

# Execute ctmldnrs to list out all manual conditions
$cmd = "ctmldnrs -CALCCOND -ADDMODE NO -OUTPUT "+ $logDir + "Manual_Conditions.txt"
iex $cmd

# Load in all manual conditions
$manualCondRaw = Get-Content ($logDir + "Manual_Conditions.txt")

# Build array of manual condition objects
foreach ($cond in $manualCondRaw){
    if ($cond -ne ""){
        $cond = $cond -split '\s+'
        $obj = new-object psobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "condition" -Value $cond[0]
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "odat" -Value $cond[1]
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "orderID" -Value $cond[2]
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "jobname" -Value $cond[3]
        $manualConds += $obj
    }
}

# Sort manual conditions by odat,jobname,conditionname
$manualConds = $manualConds | Sort-Object odat,jobname,condition


# Generate odat stats
$odatStats = $manualConds | Group-Object odat

# Start HTML Body
$htmlBody = 
    "<h3 style='Font-family: Arial'>Summary of manual conditions per condition date:</h3>
    <table style='border-collapse:collapse; Font-family: Arial'>
        <tr bgcolor=`"#f3edea`" style='Padding: 5px 10px 5px 10px; Font-family: Arial'>
            <th style='border:solid #b0d8f1 1.0pt'>Condition Date</th>
            <th style='border:solid #b0d8f1 1.0pt'>Count</th>
        </tr>"

# Build HTML Body with SUMMARY of manual conditions
foreach ($odat in $odatStats){
    $htmlBody += 
    "<tr>
        <td style='border:solid #b0d8f1 1.0pt'>"+$odat.Name+"</td>
        <td style='border:solid #b0d8f1 1.0pt'>"+$odat.Count+"</td>
    </tr>"
}

$htmlBody += 
    "</table>
    <h3 style='Font-family: Arial'>List of jobs that will not run:</h3>
    <table style='border-collapse:collapse; Font-family: Arial;border:solid #b0d8f1 1.0pt'>
        <tr bgcolor=`"#f3edea`" style='Padding: 5px 10px 5px 10px; Font-family: Arial'>
            <th style='border:solid #b0d8f1 1.0pt'>Condition Date</th>
            <th style='border:solid #b0d8f1 1.0pt'>Dependent Job</th>
            <th style='border:solid #b0d8f1 1.0pt'>Condition Name</th>
        </tr>"

# Build HTML Body with ALL manual conditions
$prevOrderID = ""
$storedRow = ""
$rowSpan = 1

foreach ($cond in $manualConds){
    # First Job
    if($prevOrderID -eq ""){
        $storedRow =
            "<tr>
                <td style='border:solid #b0d8f1 1.0pt'><font color=`"#60a7e5`">"+$cond.odat+"</td>
                <td rowspan='REPLACEME' style='border:solid #b0d8f1 1.0pt'>"+$cond.jobname+"</td>
                <td style='border:solid #b0d8f1 1.0pt'>"+$cond.condition+"</td>
            </tr>"
    }
    # Same Job
    elseif($cond.orderID -eq $prevOrderID){
        $rowSpan ++
        $storedRow +=
            "<tr>
                <td style='border:solid #b0d8f1 1.0pt'><font color=`"#60a7e5`">"+$cond.odat+"</td>
                <td style='border:solid #b0d8f1 1.0pt'>"+$cond.condition+"</td>
            </tr>"
    }
    # New Job
    else{
        # Add previous job to $htmlBody
        $htmlBody += $storedRow.Replace('REPLACEME',$rowSpan)
        
        # Store current row
        $storedRow =
            "<tr>
                <td style='border:solid #b0d8f1 1.0pt'><font color=`"#60a7e5`">"+$cond.odat+"</td>
                <td rowspan='REPLACEME' style='border:solid #b0d8f1 1.0pt'>"+$cond.jobname+"</td>
                <td style='border:solid #b0d8f1 1.0pt'>"+$cond.condition+"</td>
            </tr>"
        $rowSpan = 1
    }
    $prevOrderID = $cond.orderID
}
# Add last row
$htmlBody += $storedRow.Replace('REPLACEME',$rowSpan)

# Finish HTML Body
$htmlBody += "</table>"

# Send Email
$secureString = New-Object System.Security.SecureString
$creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "NT AUTHORITY\ANONYMOUS LOGON", $secureString
Send-MailMessage -from CTM@SITE.com -to TEAMNAME@SITE.com -subject "Manual Condition List for $date" -body $htmlBody -BodyAsHtml -credential $creds -SmtpServer mail.SITE.com

# Remove log files older than 8 days
$time = Get-Date
$ageLimit = $time.AddDays(-8)
Get-ChildItem -Path $logDir -File *_Maybe_Conditions.txt | Where-Object { !$_.PSIsContainer -and $_.LastWriteTime -lt $ageLimit } | Remove-Item -Force 
