$scriptRoot = Split-Path (Resolve-Path $myInvocation.MyCommand.Path)
. (join-path $scriptRoot "/json 1.7.ps1")

function gist { 
	Param(
		[Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
		[PSObject]$InputObject,
		[string]$Description = "",
		[string]$Username = ""
	)
	BEGIN {
		$files = @{}
	}
	PROCESS {
		if( $InputObject.GetType() -eq [System.IO.FileInfo] ) {
			$file = [System.IO.FileInfo]$InputObject
		}
		else {
			return
		}

		$path = $InputObject.FullName
		$filename = $InputObject.Name

		$content = [IO.File]::readalltext($path)

		$content = $content -replace "\\", "\\\\"
		$content = $content -replace "`t", "\t"
		$content = $content -replace "`r", "\r"
		$content = $content -replace "`n", "\n"
		$content = $content -replace """", "\"""
		$content = $content -replace "/", "\/"
		$content = $content -replace "'", "\'"

		$files.Add($filename, $content)
	}
	END {

		$apiurl = "https://api.github.com/gists"

		$request = [Net.WebRequest]::Create($apiurl)

		if($Username.length -gt 0) {
			$password = read-host "Password" -AsSecureString

			$basicpwd= [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
			$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto($basicpwd)

			$creds = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([String]::Format("{0}:{1}", $username, $password)))
			$request.Headers.Add("Authorization", "Basic " + $creds)
		}

		$request.ContentType = "application/json"
		$request.Method = "POST"

		$files.GetEnumerator() | % { 
			$singlefilejson = """" + $_.Name + """: {
					""content"": """ + $_.Value + """
			},"
	
			$filesjson += $singlefilejson
		}

		$filesjson = $filesjson.TrimEnd(',')
		
		$body = "{
			""description"": """ + $Description + """,
			""public"": true,
			""files"": {" + $filesjson + "}
		}"

		$bytes = [text.encoding]::Default.getbytes($body)
		$request.ContentLength = $bytes.Length

		$stream = [io.stream]$request.GetRequestStream()
		$stream.Write($bytes,0,$bytes.Length)

		$response = $request.GetResponse()

			
		
		$responseStream = $response.GetResponseStream()
		$reader = New-Object system.io.streamreader -ArgumentList $responseStream
		$content = $reader.ReadToEnd()
		$reader.close()

		if( $response.StatusCode -ne [Net.HttpStatusCode]::Created ) {
			$content | write-error
		}

		$result = convertfrom-json $content -Type PSObject -ForceType

		$url = $result.html_url
	
		write-output $url
	}
}
