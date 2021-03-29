/*

Author: Moin Ahmed
Case: LanDESK case 32838
Date: 04/03/2015

This script inserts import records for all users that exist in the database table Gebruiker. 
As the import process has been validated (using user LDP176 - Breheny, Tracy Melanie) we can 
now update all users to the new profile (4, Salford Locker Profile). 

If a user is blocked via the import table the Gebruiker.CardStatus field changes from 1 to 3. 
The script uses this to determin if a user has been blocked. A value of 0 in Vrij7 is NOT suspended, 
a value of 1 is suspended.
*/

BEGIN TRANSACTION LoXSProfile WITH MARK N'LoXS all users update';
BEGIN TRY
	USE [LoXS];

	INSERT INTO dbo.IMPORT (OvNr, KaartNr, Initialen, Naam, ImportFunctie, PersoonType, Klas, Vrij7, Vrij22)
	SELECT 
		Sleutelveld AS OvNr,	-- RollNumber 
		Kaartid AS KaartNr,		-- CardNumber
		LTRIM(RTRIM(RIGHT(Naam, 
			CASE WHEN CHARINDEX(',', REVERSE(Naam)) > 0 THEN CHARINDEX(',', REVERSE(Naam)) - 1 ELSE 0 END
		))) AS Initialen,		-- Forename
		LTRIM(RTRIM(
			LEFT(Naam, LEN(Naam) - CHARINDEX(',', REVERSE(Naam)))
		)) AS Naam,				-- Surname
		1 AS ImportFunctie,		-- 1 = Add/Edit personal data, 2 = Delete personal data
		1 AS PersoonType,		-- 1 = student (default), 2 = employee
		Groep AS Klas,			-- Department Code
		CASE WHEN CardStatus = 3 THEN 1 ELSE 0 END AS Vrij7, -- determine Un/suspend value based on CardStatus
		4 AS Vrij22				-- Profile
	FROM dbo.Gebruiker 
	WHERE Sleutelveld IS NOT NULL AND Kaartid IS NOT NULL -- Both required for Update
	ORDER BY ID DESC;

	COMMIT TRANSACTION LoXSProfile;
	
	PRINT 'Done...OK';
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION LoXSProfile;
END CATCH
GO
