<#
.SYNOPSIS
  This will sync Office365 / Azure AD group members to a corresponding Security Group
.DESCRIPTION
  For use case where you want an Office365 Group to sync to a Security Group used by SharePoint Online permissions, Enterprise Applications Access etc.
  For example, Team Contoso has a Microsoft Teams group where membership changes has been delegated to the Group Owner(s).
  The script will sync members to Team Contoso Security Group while also sending an email to the group to confirm changes. 
.REQUIREMENTS
  Azure AD Module
  Install-Module AzureAD
.INPUTS
  The script requires input from CSV, this can be modified to grab it from a SharePoint list if you'd like (just an idea)
  CSV Filename: Sync-GroupMemberList.csv
  CSV Format/Headers:
  DistroGroupName,DistroGroupObjectID,SecurityGroupName,SecurityGroupObjectID
  Team Contoso,sfadf2132-fdafda-431fdsfad-3423324123,Security Group - Team Contoso,dfasdf2312-fsadfads2312-fdsafe123-fdsfd

.OUTPUTS Log File
  The script log file stored in C:\Windows\Temp\<name>.log
.NOTES
  Version:        1.0
  Author:         Jerome Liwanag
  Creation Date:  5/4/2020
  Purpose/Change: Initial script development
.EXAMPLE
  Not applicable
#>

######################
# Test Mode Settings #
######################
#Set to $true to enable test mode, $false to set script perform actual actions
  $TestModeEnabled = $false
#Change to your test email
  $TestModeEmailRecipient = "YourTestEmail@domain.com" 

##################
# Authentication #
##################
#This is setup to run as a Group Managed Service Account (GMSA) - where non-interactive login are not allowed. 
#By default in Windows, encrypted password can only be used by the user who encrypted it and on the same workstation.
#If you are using a GMSA account, encrypt the password using your regular account and setup File Permissions to your GMSA account.
  $User = "ServiceAccount-IT@contoso.onmicrosoft.com"
  $PasswordFile = "C:\YourDirectory\ScriptsFolder\Config\O365.txt" #Reference on how to encrypt password for scripting https://www.pdq.com/blog/secure-password-with-powershell-encrypting-credentials-part-2/
  $KeyFile = "C:\YourDirectory\ScriptsFolder\Config\AES.key"
  $key = Get-Content $KeyFile
  $365LogonCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, (Get-Content $PasswordFile | ConvertTo-SecureString -Key $key)

#Connect using the saved credentials
  Import-Module AzureAD
  Connect-AzureAD -Credential $365LogonCred

###############
# For Logging #
###############

  $VerbosePreference = "Continue"
  $LogPath = "C:\Windows\Temp\Sync-GroupMembers\Logs"
  Get-ChildItem "$LogPath\*.log" | Where-Object LastWriteTime -LT (Get-Date).AddDays(-7) | Remove-Item -Confirm:$false
  $LogPathName = Join-Path -Path $LogPath -ChildPath "$($MyInvocation.MyCommand.Name)-$(Get-Date -Format 'MM-dd-yyyy')-$env:USERNAME.log"
  Start-Transcript $LogPathName -Append

  Write-Verbose "$(Get-Date): Start Log..."

#CSV File Path
  $GroupList = "C:\YourDirectory\ScriptsFolder\Sync-GroupMemberList.csv"
    Import-Csv $GroupList | ForEach-Object {
        $DistroGroupObjectID = $_.DistroGroupObjectID
        $SecurityGroupObjectID = $_.SecurityGroupObjectID
        $DistroGroupName = $_.DistroGroupName
        $SecurityGroupName = $_.SecurityGroupName

        #Get the members of the group

          $DistroGroupMembers = Get-AzureADGroupMember -ObjectId $DistroGroupObjectID| Select-Object -ExpandProperty UserPrincipalName
          $SecurityGroupMembers = Get-AzureADGroupMember -ObjectId $SecurityGroupObjectID | Select-Object -ExpandProperty UserPrincipalName
        #Get the deltas and write them out (for logging purpose)
          $Deltas = Compare-Object $DistroGroupMembers $SecurityGroupMembers
          $DeltasCount = ($Deltas | Measure-Object).Count
          Write-Host "The difference in members are $DeltasCount"
        
        #Process the sync
          $Result = foreach ($item in $Deltas) {
            $Member = $Item.InputObject
            $Indicator = $Item.SideIndicator
            $MemberAADObject = Get-AzureADUser -ObjectId $Member
                if ($Indicator -eq "<="){
                    Write-Output "<li>$Member is a member of the reference group '$DistroGroupName' but not part of '$SecurityGroupName', adding user as a member of '$SecurityGroupName'</li>"
                    #Test setting condition, if TestModeEnabled is set to false (or not equal to $true), then perform the action.
                        if ($TestModeEnabled -ne $true){
                            Add-AzureADGroupMember -ObjectId $SecurityGroupObjectID -RefObjectId $MemberAADObject.ObjectId
                            } #end of Test Mode IF STATEMENT
                    } else{
                    Write-Output "<li>$Member is a member of '$SecurityGroupName' but no longer part of the reference group '$DistroGroupName', removing user as member of '$SecurityGroupName'</li>"
                    #Test setting condition, if TestModeEnabled is set to false (or not equal to $true), then perform the action.    
                        if ($TestModeEnabled -ne $true){
                            Remove-AzureADGroupMember -ObjectId $SecurityGroupObjectID -MemberId $MemberAADObject.ObjectId 
                            } #end of Test Mode IF STATEMENT
                    }
            }  #end of deltas foreach loop
    
####################################
# Email Communication and Settings #
####################################

#Send communicaion if there are changes only
    If($DeltasCount -gt 0){
        #Email settings are configured to authenticate through Office365 SMTP, change them as necessary.
        $PSEmailServer = "smtp.office365.com"
        $SMTPPort = 587
        $SMTPUsername = "IT-servicemailbox@contoso.com"
        $EmailCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SMTPUsername, (Get-Content $PasswordFile | ConvertTo-SecureString -Key $key)
        $MailFrom = "IT-servicemailbox@contoso.com"
        $MailSubject = "ATTN: $SecurityGroupName has been updated"
        #Check for Test Mode
          if ($TestModeEnabled -eq $true){
            $MailTo = $TestModeEmailRecipient
          }else{
            $MailTo = (Get-AzureADGroup -ObjectId $DistroGroupObjectID).Mail
          } #end of test mode email if statement       
        $MailBody = @"

<p>Hello,</p>

<p>
<br>The distribution group ($DistroGroupName) has been set to sync with the group '$SecurityGroupName'.
<br>Please review the actions below and the confirm member needs resources assigned to '$SecurityGroupName'
<br>
<br>If the member is not supposed to be part of the security group, simply remove the member from the distribution group and the script will sync the members again within the next hour.
<br>If you need immediate assistance, please create a ticket or email ITSupport@contoso.com.
</p>

<p>Thanks,<br>
IT Support | Sync-GroupMembers Script @ $env:COMPUTERNAME
</p>

<br>---
<br>Number of changes: $DeltasCount
<br>Results:<br>
<ul>
$Result
</ul>
"@

    #Send email command
    Send-MailMessage -From $MailFrom -To $MailTo -Subject $MailSubject -Body $MailBody -Port $SMTPPort -Credential $EmailCredential -UseSsl -BodyAsHtml

    }#end of email If statement
} #end of main foreach loop
#STOP THE LOGGING
Stop-Transcript 