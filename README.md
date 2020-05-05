# SYNOPSIS
Sync-GroupMembers\
This will sync Office365 / Azure AD group members to a corresponding Security Group
# DESCRIPTION
For use case where you want an Office365 Group to sync to a Security Group used by SharePoint Online permissions, Enterprise Applications Access etc.\
For example, Team Contoso has a Microsoft Teams group where membership changes has been delegated to the Group Owner(s).\
The script will sync members to Team Contoso Security Group while also sending an email to the group to confirm changes.
# REQUIREMENTS
Azure AD Module\
Install-Module AzureAD
# INPUTS
The script requires input from CSV, this can be modified to grab it from a SharePoint list if you'd like (just an idea).\
CSV Filename:\
Sync-GroupMemberList.csv\
CSV Format/Headers:\
DistroGroupName,DistroGroupObjectID,SecurityGroupName,SecurityGroupObjectID\
Team Contoso,sfadf2132-fdafda-431fdsfad-3423324123,Security Group - Team Contoso,dfasdf2312-fsadfads2312-fdsafe123-fdsfd

# OUTPUTS Log File
The script log file stored in C:\Windows\Temp\<name>.log\
# NOTES
Version:1.0\
Author:Jerome Liwanag\
Creation Date:5/4/2020\
Purpose/Change: Initial script development
# EXAMPLE
Not applicable
