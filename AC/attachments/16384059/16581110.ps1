# TG - 12/9/2011
# v2 - 31/07/2012

import-module ActiveDirectory
$DebugPreference = "Continue"

# Move Functional Accounts out of the way

Write-Debug "Moving Functional Accounts.."

Get-ADUser -LdapFilter "(title=Functional)" -SearchBase "OU=Students,OU=Users,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk" -ResultSetSize $null | Move-ADObject -TargetPath "OU=Functional,OU=Users,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk" -PassThru
Get-ADUser -LdapFilter "(title=Functional)" -SearchBase "OU=Staff,OU=Users,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk" -ResultSetSize $null  | Move-ADObject -TargetPath "OU=Functional,OU=Users,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk" -PassThru

# Move staff out of student OU

Write-Debug "Moving Staff..."

Get-ADUser -LdapFilter "(uosaffiliation=Staff)" -SearchBase "OU=Students,OU=Users,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk" -ResultSetSize $null  | Move-ADObject -TargetPath "OU=Staff,OU=Users,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk" -PassThru


# Add new staff and students to security groups

Write-Debug "Adding new Staff to Staff Group"

Get-ADUser -SearchBase "OU=Staff,OU=Users,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk" -ResultSetSize $null  -Filter 'MemberOf -ne "CN=All Staff Security Group,OU=Non-Provisioned,OU=Groups,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk"' | Add-ADPrincipalGroupMembership -MemberOf "All Staff Security Group" -Confirm:$false -PassThru

Write-Debug "Adding new Students to Student Group"

Get-ADUser -SearchBase "OU=Students,OU=Users,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk" -ResultSetSize $null -Filter 'MemberOf -ne "CN=All Students Security Group,OU=Non-Provisioned,OU=Groups,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk"' | Add-ADPrincipalGroupMembership -MemberOf "All Students Security Group" -Confirm:$false -PassThru

# Remove old students from security group - leaving staff alone as need to cope with Infrastructure Admin

Write-Debug "Removing old Students from Student Group"

Get-ADUser -ResultSetSize $null -Filter 'MemberOf -eq "CN=All Students Security Group,OU=Non-Provisioned,OU=Groups,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk"' | where {$_.DistinguishedName -notlike "CN=*,OU=Students,OU=Users,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk" } | Remove-ADPrincipalGroupMembership -MemberOf "All Students Security Group" -Confirm:$false -PassThru


