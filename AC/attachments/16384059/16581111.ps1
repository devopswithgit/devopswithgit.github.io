add-pssnapin microsoft.exchange.management.powershell.E2010
get-mailcontact -OrganizationalUnit 'University - Students' -filter {LegacyExchangeDN -eq $Null} | Format-Table >> c:\sharedscripts\logfiles\student-contact-records.log
get-mailcontact -OrganizationalUnit 'University - Students' -filter {LegacyExchangeDN -eq $Null} | update-recipient
