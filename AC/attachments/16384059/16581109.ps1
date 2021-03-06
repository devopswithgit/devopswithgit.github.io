import-module ActiveDirectory

$dc = "uos-p-domc-01.isdads.salford.ac.uk"
$sqluidnumber = "SELECT uidNumber FROM posixAccount WHERE username = ?"
$studentstofix = $null
$stafftofix = $null

$DebugPreference = "Continue"

$dbconn = new-object system.data.odbc.odbcconnection
$dbconn.ConnectionString = "DSN=Accman;Driver=MySQL ODBC 3.51 Driver"
$dbconn.Open()

$dbcomm = $dbconn.CreateCommand()
$dbcomm.CommandText = $sqluidnumber
$dbcomm.Parameters.Add("username","")
$dbcomm.Prepare()

$studentstofix = get-aduser -LDAPFilter "(|(!(gidNumber=*))(!(unixHomeDirectory=*))(!(uidNumber=*)))" -ResultSetSize $null -SearchBase "OU=Students,OU=Users,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk" -Server $dc -Properties uidNumber,gidNumber,unixHomeDirectory
$stafftofix = get-aduser -LDAPFilter "(|(!(gidNumber=*))(!(unixHomeDirectory=*))(!(uidNumber=*)))" -ResultSetSize $null -SearchBase "OU=Staff,OU=Users,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk" -Server $dc -Properties uidNumber,gidNumber,unixHomeDirectory

if (!$studentstofix -and !$stafftofix)
{
  $userstofix = $null
}
elseif (!$studentstofix) 
{
  $userstofix = $stafftofix
}
elseif (!$stafftofix)
{
  $userstofix = $studentstofix
}
else
{
  $userstofix = $studentstofix + $stafftofix
}

if (!$userstofix)
{
  Write-Debug "Nothing to fix"
  return
}

$userstofix | foreach {
    $thisuid = $null
    $samAccountName = $_.SamAccountName
      
    $dbcomm.Parameters[0].Value = $samAccountName
    
    $samAccountName = $samAccountName.ToLower().Trim()
    
    $thisuid = $dbcomm.ExecuteScalar()
    if ($thisuid)
    {
      $_.uidNumber = $thisuid
      $_.gidNumber = "1001"
      $_.unixHomeDirectory = "/home/$samAccountName"
      Write-Debug "Set-aduser $samAccountName with uid $thisuid and unixhomedirectory $($_.unixHomeDirectory)"
      set-aduser -instance $_ -Server $dc
    }
    else
    {
      write-debug "Couldn't get uid for $samAccountName from AccMan"
    }
}

$mmstofix = get-aduser -LDAPFilter "(&(samAccountName=mms*)((|(!(gidNumber=*))(!(unixHomeDirectory=*))(!(uidNumber=*)))))" -ResultSetSize $null -SearchBase "OU=Functional,OU=Users,OU=Non Datacentre,DC=isdads,DC=salford,DC=ac,DC=uk" -Server $dc -Properties uidNumber,gidNumber,unixHomeDirectory

if (!$mmstofix)
{
  Write-Debug "No mms to fix"
  return
}

$mmstofix | foreach {
    $thisuid = $null
    $samAccountName = $_.SamAccountName
      
    $dbcomm.Parameters[0].Value = $samAccountName
    
    $samAccountName = $samAccountName.ToLower().Trim()
    
    $thisuid = $dbcomm.ExecuteScalar()
    if ($thisuid)
    {
      $_.uidNumber = $thisuid
      $_.gidNumber = "1001"
      $_.unixHomeDirectory = "/home/$samAccountName"
      Write-Debug "Set-aduser $samAccountName with uid $thisuid and unixhomedirectory $($_.unixHomeDirectory)"
      set-aduser -instance $_ -Server $dc
    }
    else
    {
      write-debug "Couldn't get uid for $samAccountName from AccMan"
    }
}

$dbconn.Close()