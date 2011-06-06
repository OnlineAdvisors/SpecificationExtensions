$nuget = (get-item .\tools\NuGet\NuGet.exe)

function Get-Last-NuGet-Version($nuGetPackageId) {
	$feeedUrl = "http://packages.nuget.org/v1/FeedService.svc/Packages()?`$filter=Id%20eq%20'$nuGetPackageId'"
	$webClient = new-object System.Net.WebClient
	$queryResults = [xml]($webClient.DownloadString($feeedUrl))
	$version = $queryResults.feed.entry | %{ $_.properties.version } | sort-object | select -last 1

	if(!$version){
		$version = "0.0"
	}

	$version
}

function Increment-Version($version){
    $parts = $version.split('.')
    for($i = $parts.length-1; $i -ge 0; $i--){
        $x = ([int]$parts[$i]) + 1
        if($i -ne 0) {
            # Don't roll the previous minor or ref past 10
            if($x -eq 10) {
                $parts[$i] = "0"
                continue
            }
        }
        $parts[$i] = $x.ToString()
        break;
    }
    [System.String]::Join(".", $parts)
}

$packageIds = @( @{} )
$packageIds[0].Name = "Xunit"
$packageIds[0].PackageId = "SpecificationExtensions.Xunit"
$packageIds[0].SpecFile = (get-item ".\Xunit\xUnitSpecificationExtensions.cs")

$baseNuSpecFile = (get-item .\SpecificationExtensions.Base.nuspec)

$buildRoot = ".\NuGetBuild"
rm $buildRoot -force -recurse -ErrorAction SilentlyContinue
mkdir $buildRoot | out-null

pushd $buildRoot
	foreach($package in $packageIds){
		$package.OldVersion = Get-Last-NuGet-Version $package.PackageId
		$package.NewVersion = Increment-Version $package.OldVersion
		
		mkdir $package.Name | out-null
		pushd $package.Name
			mkdir "content\SpecExtensions" | out-null
			cp $package.SpecFile "content\SpecExtensions"
			$nuspecFile = "$($package.PackageId).$($package.NewVersion).nuspec"
			cp $baseNuSpecFile $nuspecFile
			$nuspec = [xml](cat $baseNuSpecFile)
			$nuspec.package.metadata.version = $package.NewVersion
			$nuspec.package.metadata.id = $package.PackageId
			$nuspec.package.metadata.description = "A set of C# specification extension methods that provide an easy to use 'testObject.Should***()' syntax for use with $($package.Name)"
			$nuspec.Save((get-item $nuspecFile))

			& $nuget pack $nuspecFile
		popd
	}
popd
