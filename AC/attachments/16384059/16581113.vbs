'----------------------------------------------------
' 
' SALSync Student Contact importer
'
' (c) 2007 Michael Hall
'     University of Salford
'
' V1 - Stable release - for ISDADS domain testing
' V1.1 - Proxy and Target email addresses were not Primary (uppercase "SMTP:") addresses.
' V1.2 - set "mAPIRecipient" to False for all contacts and changed related error checking.
'
' V2 - Huge error checking and delay tactics added to the script, when it has problems 
' contacting the AD with "Table not found" type errors, it waits for a few seconds, then  
' rebuilds the connections and tries again, up to about 10 times.  If it continues to fail, 
' it gives up on that particular record and moves on.
'
'----------------------------------------------------

Option Explicit

Const strODBCName = "Mail"

Const ForAppending = 8
Const ForWriting = 2
Const ADS_SCOPE_SUBTREE = 2
Const ADS_SECURE_AUTHENTICATION = 1
Const ADS_SERVER_BIND = 512
Const strADDomainDN = "DC=ISDADS,DC=Salford,DC=ac,DC=uk"
Const strADOUDN = "OU=University - Students"
Const strADServer = "uos-p-domc-05.isdads.salford.ac.uk:389/"

'Alternate AD credentials
Const strADUserOUDN = "cn=Users"
Const strADUsername = "SalSync"
Const strADPW = "Ssync567#"

Function toErrorStr(Error)
	Dim hexError
	hexError = Hex(Error)
	Select Case HexError
		Case "80071392"
			toErrorStr = hexError & " (Object already exists)"
		Case Else 
			toErrorStr = hexError
	End Select
End Function

Sub DBGLog(strLog)
	WScript.Echo strLog
	Dim objFSO, fsLogFile
	Set objFSO = CreateObject("Scripting.FileSystemObject")
	Set fsLogFile = objFSO.OpenTextFile("C:/Scripts/Logs/DebugLog.txt", ForAppending, True)
	fsLogFile.WriteLine now() & " " & strLog
	fsLogFile.Close
end Sub

Sub Log(strLog)
	WScript.Echo strLog
	fsLogFile.WriteLine now() & " " & strLog
End Sub

Sub StatsLog(strStat)
	fsStatsFile.WriteLine now() & " " & strStat
End Sub

Sub FailLog(strStat)
	WScript.Echo strStat
	fsFailFile.WriteLine now() & " " & strStat
End Sub

Function IsContactInAccman(strEmail)
	Dim strSQLQuery
	Dim objDBRS
	Dim pos, strPrefix, strSuffix
	pos = instr(strEmail,"@")
	strPrefix = mid(strEmail,1,pos - 1)
	strSuffix = mid(strEmail,pos + 1)
	strSQLQuery = "SELECT state" & _
		" FROM Mail.account, Mail.person, Mail.emailDomain" & _
		" WHERE account.primary_mailname = """ & strPrefix & """" & _
		" AND emailDomain.domainName = """ & strsuffix & """" & _
		" AND state = ""valid"" AND person_state in (""present"",""extended"",""graduating"",""expected"") AND source_code = 'S' AND accountType = 'personal'" & _
		" AND account.personID = person.personID AND account.primary_domainID = emailDomain.domainID"
	Set objDBRS = CreateObject("ADODB.Recordset")

	objDBRS.Open strSQLQuery, objDBConnection, 3, 3
	
	If objDBRS.EOF then 
		IsContactInAccman = False
	else
		IsContactInAccman = True
	end if
	objDBRS.Close
	Set objDBRS = Nothing
End Function

Sub DeleteOldStudentContacts
	Dim objRecordSet, objUser
	Dim Count, CountDel
	Dim strEmail, strADDN, strError

	Count = 0
	CountDel = 0
	DBGLog "Performing search in AD for deletable contacts"
	
	objCommand.CommandText = "<LDAP://" & strADServer & strADOUDN & "," & strADDomainDN & ">;(objectClass=Contact)" & _
			";mail,DistinguishedName"
	Set objRecordSet = objCommand.Execute
	DBGLog "Comparing AD contacts with accman for validity"
	on error resume next
	Do While not objRecordset.EOF
		strEmail = objRecordSet.fields("mail").Value
		If Not isNull(strEmail) then 
			If Not isContactInAccman(strEmail) Then
				strADDN = objRecordSet("DistinguishedName")
				Log "Delete account " & strADDN
				Set objUser = objADRoot.OpenDSObject("LDAP://" & strADServer & strADDN, "CN=" & strADUserName & "," & strADUserOUDN & "," & strADDomainDN, strADPW, ADS_SERVER_BIND)
				If err.number <> 0 then 
					strError = "Failed to open contact for deletion " & strADDN & " - " & toErrorStr(err.number) & " " & err.Description
					Log " Error - " & strError 
					FailLog strError
					err.Clear
				else
					objUser.DeleteObject(0)
					If err.number <> 0 then 
						strError = "Failed to delete " & strADDN & " - " & toErrorStr(err.number) & " " & err.Description
						Log " Error - " & strError
						FailLog strError
						err.Clear
					end if
				end if
				CountDel = CountDel + 1			
			End If	
		End If
		objRecordSet.MoveNext
		Count = Count + 1
	Loop
	objRecordSet.Close
	Set objRecordSet = Nothing
	StatsLog Count & " contacts checked, " & CountDel & " removed from AD"
	DBGLog "Finished delete search"
End Sub

Function FindContactInAD(strEmail)
	Dim objRecordSet, strCommandText, strError, iLoops
	iLoops = 0
	strCommandText = "<LDAP://" & strADServer & strADOUDN & "," & strADDomainDN & ">;(&(objectClass=Contact)" & _
			"(mail=" & strEmail & "));DistinguishedName"
	Log strCommandText
	Do
		objCommand.CommandText = strCommandText
		On Error Resume Next
		Set objRecordSet = objCommand.Execute
		If Err.number <> 0 then 
			Log "  Waiting for AD to catch up - " & toErrorStr(err.number) & " " & err.Description
			on error goto 0
			WScript.Sleep 3000
			OpenADConnObj
			err.clear
		Else 
			on error goto 0
			If objRecordset.RecordCount = 0 Then
				FindContactInAD = "Not found"
			end if
			If objRecordset.RecordCount = 1 Then
				objRecordSet.MoveFirst
				FindContactInAD = objRecordSet.fields("distinguishedName").value
			End If
			If objRecordset.RecordCount > 1 then 
				Log "  Note - More than 1 contact found in AD for updating for " & strEmail
				FindContactInAD = "Failed"
			end if
		End If	
		iLoops = iLoops + 1
	Loop until iLoops = 10 or FindContactInAD <> ""
	If FindContactInAD = "" then
		strError = "Failed to perform LDAP search " & strCommandText
		FailLog strError
		FindContactInAD = "Failed"
	end if
	on error resume next
	objRecordSet.Close
	Set objRecordSet = Nothing
End Function

Function FormatDisplayName(strFirstName, strInitials, strLastname)
  If strFirstName <> "" Then
      FormatDisplayName = strLastName & " " & strFirstName
  Else
      FormatDisplayName = strLastName & " " & strInitials
  End If
End Function

Sub SetUserInfo(objUser, strItem, strValue, ChangesWereMade, ChangesMade)
	Dim OldValue, strError, OldValueUcase
	OldValue = "<empty>"
	On Error Resume Next
	OldValue = objUser.Get(strItem)
	Select Case Err.Number
		Case 0
		Case &H8000500D
			' not found in the cache
			OldValue = "empty"
			err.Clear
		Case Else
			strError = "(SetUserInfo - Get) Failed to compare attribute " & strItem & " = " & strValue & " for " & objUser.DistinguishedName & " - " & toErrorStr(err.number) & " - " & err.Description
			FailLog strError
			err.Clear
	End Select
	On Error Resume Next
	if isEmpty(OldValue) or isNull(OldValue) then OldValue = "empty"
	OldValueUcase = Ucase(OldValue)
	if OldValueUcase = "FALSE" or OldValueUcase = "TRUE" then OldValue = OldValueUcase
	If OldValue <> strValue then 
		ChangesWereMade = True
		ChangesMade = ChangesMade + 1
		objUser.Put strItem, strValue 
		If Err.number <> 0 then 
			strError = "(SetUserInfo - Put) Failed to change attribute " & strItem & " to " & strValue & " for " & objUser.DistinguishedName & " - " & toErrorStr(err.number) & " - " & err.Description
			Log " Error - " & strError
			FailLog strError
			err.Clear
		Else
			Log "  attribute " & strItem & " changed to " & strValue & ", was " & OldValue
		End If

	End If
End Sub

Sub SaveUserInfo(objUser, strSection)
	Dim strError
	On Error Resume Next
	objUser.SetInfo
	if err.number <> 0 then 
		strError = "Failed to set info on contact - " & strSection & " - " & toErrorStr(err.number) & " " & err.Description
		on error goto 0
		Log " Error - " & strError
		FailLog strError
		err.Clear
	end if
End Sub

Function CreateUpdateADContact(strMode, strADobj, strStuLevel, strFirstName, strInitials, strLastname, strEmail, strMailname, strCourse, strStuDegc, strYrCourse, strDeptCode)
	Dim strDisplayName, strObjectName, strError
	Dim objADOU, objUser
	Dim ChangesWereMade, ChangesMade
	Dim strOldStuLevel, strNewParent, objNewParent
	
	err.clear
	strDisplayname = formatdisplayname(strFirstname, strInitials, strLastname) & " (" & strMailname & ") " & strStuLevel
	strObjectName = strDisplayName
	If Len(StrObjectName) > 64 then 
		strObjectname = formatdisplayname(strFirstname, strInitials, strLastname) & " " & strStuLevel 
	End If
'	On Error Resume Next
	Select Case lcase(strMode)
		Case "create"
			strADobj = "OU=" & strStuLevel & "," & strADOUDN & "," & strADDomainDN
			Log "Creating " & strObjectname
			Set objADOU = objADRoot.OpenDSObject("LDAP://" & strADServer & strADobj, "CN=" & strADUserName & "," & strADUserOUDN & "," & strADDomainDN, strADPW, ADS_SERVER_BIND)
			if err.number <> 0 then 
				strError = "Failed to open OU for " & strStuLevel & " - " & toErrorStr(err.number) & " " & err.Description
				Log " Error - " & strError
				FailLog strError
				err.Clear
			else
				Set objUser = objADOU.Create("contact", "cn=" & strObjectName)
				If err.number <> 0 then 
					strError = "Failed to create contact " & strDisplayName & " - " & toErrorStr(err.number) & " " & err.Description
					Log " Error - " & strError
					FailLog strError
					err.Clear
				end if
			end if
		Case "update"
			Log "Updating " & strADobj
			Set objUser = objADRoot.OpenDSObject("LDAP://" & strADServer & strADobj, "CN=" & strADUserName & "," & strADUserOUDN & "," & strADDomainDN, strADPW, ADS_SERVER_BIND)
			If err.number <> 0 then 
				Log " Error - Failed to open contact for updating " & strADobj & " - " & toErrorStr(err.number) & " " & err.Description
				err.Clear
				exit function
			end if
	End Select
	ChangesMade = 0
	ChangesWereMade = False
	SetUserInfo objUser, "displayName", strDisplayName, ChangesWereMade, ChangesMade
	If ChangesWereMade then SaveUserInfo objUser, "DisplayName Details for " & strEmail

	ChangesWereMade = False
	SetUserInfo objUser, "msExchPoliciesExcluded", "{26491CFC-9E50-4857-861B-0CB8DF22B5D7}", ChangesWereMade, ChangesMade
	SetUserInfo objUser, "mAPIRecipient", "TRUE", ChangesWereMade, ChangesMade
	SetUserInfo objUser, "proxyAddresses", "SMTP:" & strEmail, ChangesWereMade, ChangesMade
	SetUserInfo objUser, "targetAddress", "SMTP:" & strEmail, ChangesWereMade, ChangesMade
	SetUserInfo objUser, "mailNickname", strMailname, ChangesWereMade, ChangesMade
	SetUserInfo objUser, "internetEncoding", 1310720, ChangesWereMade, ChangesMade
	SetUserInfo objUser, "mail", strEmail, ChangesWereMade, ChangesMade
	If ChangesWereMade then SaveUserInfo objUser, "Exchange Details for " & strEmail
	
	ChangesWereMade = False
	SetUserInfo objUser, "sn", strLastname, ChangesWereMade, ChangesMade
	SetUserInfo objUser, "initials", strInitials, ChangesWereMade, ChangesMade
	SetUserInfo objUser, "givenName", strFirstname, ChangesWereMade, ChangesMade
	SetUserInfo objUser, "department", strCourse, ChangesWereMade, ChangesMade
	SetUserInfo objUser, "company", strStuDegc, ChangesWereMade, ChangesMade
	SetUserInfo objUser, "physicalDeliveryOfficeName", strDeptCode, ChangesWereMade, ChangesMade
	SetUserInfo objUser, "title", strStuLevel, ChangesWereMade, ChangesMade
	' SetUserInfo objUser, "postalCode", cStr(strYrStudent), ChangesWereMade, ChangesMade ' now obsolete 
	SetUserInfo objUser, "postalCode", cStr(strYrCourse), ChangesWereMade, ChangesMade ' was mapped to "postOfficeBox"
	If ChangesWereMade then SaveUserInfo objUser, "Person Details for " & strEmail
	
	If Len(objUser.Name) < 3 Then
		' Unlikely but if we have a contact with less than 3 characters in the CN the script
		' wouldn't behave correctly, so force it not to move it
		strOldStuLevel = strStuLevel
	Else
		strOldStuLevel = Trim(Mid(objUser.Name, Len(objUser.Name)-2))
	End If
	
	If strOldStuLevel <> strStuLevel Then
		Err.Clear
		On Error Resume Next
		
		Log "Moving contact for " & strEmail & " due to change in level code"
		strNewParent = "OU=" & strStuLevel & "," & strADOUDN & "," & strADDomainDN
		
		Set objNewParent = objADRoot.OpenDSObject("LDAP://" & strADServer & strNewParent, "CN=" & strADUserName & "," & strADUserOUDN & "," & strADDomainDN, strADPW, ADS_SERVER_BIND)
		
		objNewParent.MoveHere objUser.AdsPath, "cn=" & strObjectname
		If Err.Number <> 0 Then
			FailLog "Could not move contact to " & strNewParent & " for " & strEmail
		Else
			Log "Contact moved to " & strNewParent & " for " & strEmail
			ChangesMade = ChangesMade + 1
		End If
		On Error GoTo 0
		Err.Clear
	End If			
	
	strADobj = objUser.DistinguishedName
	If ChangesMade > 0 then 
		CreateUpdateADContact = "  Done with " & ChangesMade & " attribute changes made to " & strADobj 
	Else 
		CreateUpdateADContact = ""
	End If
	Set objUser = Nothing
	Set objADOU = Nothing
End Function

Sub EnumerateContacts
	Dim objDBRS
	Dim strResult
	Dim strADobj, strMode
	Dim strInitials, strFirstName, strLastName, strEmail, strDepartment, strDisplayName, strMailName
	Dim strDeptCode, strStuDegc, strYrCourse ' strYrStudent is now obsolete
	Dim strSQLQuery, objLargeInt, objGet
	Dim strCourse, strStuLevel
	Dim UCount, CCount

	strSQLQuery = "SELECT Initials, RealName, forenames, " & _ 
		"   dept.full_name as dept_name, " & _ 
		"   if(stu_levl = 'PG', if(qual_aim_code = 02, 'PGR', 'PGT'), 'UG') as stu_type, " & _
		"   yr_course, title, program, " & _ 
		"   stu_degc, preferredName, start_date, primary_mailname, " & _ 
		"   concat(account.primary_mailname,""@"",pri_domains.domainName) as address " & _
		" FROM Mail.person, Mail.account, Mail.emailDomain as pri_domains, Mail.dept " & _
		" WHERE state = ""valid"" AND person_state in (""present"",""extended"",""graduating"",""expected"") AND source_code = ""S"" " & _
		" AND accountType = ""personal"" AND account.personID = person.personID " & _
		" AND account.primary_domainID = pri_domains.domainID AND dept.dept_code = person.dept_code" 
		' Changed dept_code to dept_name
		' Removed yr_student, sos_code and person_status_code
		' Removed stu_styp, acad_sess, reg_status, leaver_flag, stu_term, username
		' Removed stu_block, stu_stst, stu_ests, stu_att, status_code
	
	DBGLog "Performing Accman Search for needed contacts"
	Set objDBRS = CreateObject("ADODB.Recordset")
	objDBRS.Open strSQLQuery, objDBConnection, 3, 3
 
	DBGLog "Working on Accman Recordset"
	UCount = 0
	CCount = 0 
	While not objDBRS.EOF
		strEmail = CStr(objDBRS("address"))		
		If not isNull(strEmail) then
			strFirstname = objDBRS("preferredName")
			strLastname = objDBRS("RealName")
			strInitials = objDBRS("Initials")
			strMailname = objDBRS("primary_mailname")
			strStuLevel = objDBRS("stu_type") ' Changed from stu_levl
			strCourse = objDBRS("program") ' Changed from stu_block
			strStuDegc = objDBRS("stu_degc")
			strDeptCode = objDBRS("dept_name")
			' strYrStudent = objDBRS("yr_student") ' Obsolete
			' if isNull(strYrStudent) then strYrStudent = "" ' Obsolete
			strYrCourse = objDBRS("yr_course")
			if isNull(strYrCourse) then strYrCourse = ""
			
			strADobj = FindContactInAD(strEmail)
			Select Case strADobj
				Case "Failed"
					strMode = ""
				Case "Not found"
					strMode = "Create" 
					strADobj = "new contact"
					CCount = CCount + 1
				Case Else
					strMode = "Update"
					UCount = UCount + 1
			End Select
			Log UCount + CCount & " - " & strMode & " object " & strEmail
			If strMode <> "" then 
				strResult = CreateUpdateADContact(strMode, strADobj, strStuLevel, strFirstName, strInitials, strLastname, strEmail, strMailname, strCourse, strStuDegc, strYrCourse, strDeptCode)
			Else
				strResult = "Failed to check LDAP for " & strEmail
			End If
			If StrResult <> "" then Log strResult
		End If
		objDBRS.MoveNext
	Wend
	StatsLog Ccount & " student records created in AD."
	StatsLog UCount & " student records already in AD and checked."
	objDBRS.Close
	Set objDBRS = Nothing
	DBGLog "Finished Updateing records"
End Sub

Sub OpenADConnObj
	On Error Resume Next
	objADConnection.Close
	Set objADConnection = Nothing
	Set objCommand = Nothing
	On Error Goto 0
	Set objADConnection = CreateObject("ADODB.Connection")
	objADConnection.Provider = "ADsDSOObject"
	objADConnection.Properties("User ID") = strADUsername
	objADConnection.Properties("Password") = strADPW
	objADConnection.Properties("Encrypt Password") = TRUE
	objADConnection.Properties("ADSI Flag") = 1 
	objADConnection.Open "Active Directory Provider"
	
	Set objCommand = CreateObject("ADODB.Command")
	objCommand.ActiveConnection = objADConnection
	objCommand.Properties("Page Size") = 50000
	objCommand.Properties("Timeout") = 30
	objCommand.Properties("Searchscope") = ADS_SCOPE_SUBTREE
	'objCommand.Properties("Cache Results") = False
End Sub

Dim objFSO, fsLogFile, fsStatsFile, fsFailFile

Set objFSO = CreateObject("Scripting.FileSystemObject")
Set fsLogFile = objFSO.OpenTextFile("C:/Scripts/Logs/ActionsLog.txt", ForWriting, True)
Set fsStatsFile = objFSO.OpenTextFile("C:/Scripts/Logs/Stats.txt", ForAppending, True)
Set fsFailFile = objFSO.OpenTextFile("C:/Scripts/Logs/Failures " & Replace(FormatDateTime(Date(),2),"/","-") & ".txt", ForAppending, True)

StatsLog ">>> Started"

DBGLog "Creating AD Connection object"

Dim objADConnection
Dim objCommand
OpenADConnObj

Dim objADRoot, objADBind
Set objADRoot = GetObject("LDAP:")
DBGLog "Connecting to LDAP source """ & strADServer & strADOUDN & "," & strADDomainDN & """"
Set objADBind = objADRoot.OpenDSObject("LDAP://" & strADServer & strADOUDN & "," & strADDomainDN, "CN=" & strADUserName & "," & strADUserOUDN & "," & strADDomainDN, strADPW,  ADS_SERVER_BIND)
DBGLog "Done"

DBGLog "Creating ODBC Connection object"
Dim objDBConnection
Set objDBConnection = CreateObject("ADODB.Connection")
DBGLog "Connecting to ODBC source """ & strODBCName & """"
on error resume next
objDBConnection.Open strODBCName
If err.number <> 0 then 
	DBGLog "Failed to connect to " & strODBCName
	DBGLog err.description
Else 
	On Error Goto 0
	DeleteOldStudentContacts
	objADConnection.Properties.Refresh
	EnumerateContacts
end if
DBGLog ">>> Finished"
StatsLog ">>> Finished"

On Error Resume Next
Set objCommand = Nothing
objADConnection.Close
Set objADConnection = Nothing

objDBConnection.Close
Set objDBConnection = Nothing

fsFailFile.Close
fsStatsFile.Close
fsLogFile.Close