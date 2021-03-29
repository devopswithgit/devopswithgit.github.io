$file_dir = Read-Host "Type the directory path to create CSV"
if((Test-Path $file_dir) -Eq 0)
{
	mkdir $file_dir|out-null;
}
$file = Read-Host "Please choose a name for the CSV file"
if(!([IO.Path]::GetExtension($file) -Eq '.csv'))
{
	$file = $file + ".csv";
}
Out-File -FilePath "$file_dir\$file";
$path = Read-Host "Type the path to the DLL to document"
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
	$header | Out-File -FilePath "$file_dir\$file" -Encoding "UTF8";
	$output | Out-File -FilePath "$file_dir\$file" -Append;
}
catch
{
	$_.LoaderExceptions | %
	{
		Write-Error $_.Message
	}
}