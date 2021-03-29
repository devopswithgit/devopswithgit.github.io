$file = 'C:\dev\AccManLibraryMethods.csv';
$path = 'C:\VS2010\.NET\Accman.NET\AccManLibrary\bin\Debug\AccManLibrary.dll';
$exclude_class_regex = '^((?!(<)).)*$';
$exclude_method_regex = '^((?!(get_|set_)).)*$';
$Assembly = [System.Reflection.Assembly]::LoadFrom($path);
try
{
	$Types = $Assembly.GetTypes()|Where{$_.Name -Match $exclude_class_regex};
	$header = "Class,Method,ReturnType";
	$output = ForEach($Type in $Types|Sort-Object -Property Name)
	{
		$MethodList = $Type.GetMethods()|?{$_.IsPublic}|Where{$_.Name -Match $exclude_method_regex};
		ForEach($Method in $MethodList|Sort-Object -Property Name)
		{
			$Type.Name+','+$Method.Name+','+$Method.ReturnType;
		}
	}
	$header | Out-File -FilePath $file -Encoding "UTF8";
	$output | Out-File -FilePath $file -Append;
}
catch
{
	$_.LoaderExceptions | %
	{
		Write-Error $_.Message
	}
}