$scriptRoot = Split-Path (Resolve-Path $myInvocation.MyCommand.Path)
. (join-path $scriptRoot "/json 1.7.ps1")

function gist { Param(
	[io.fileinfo]$File,
	[string]$Description = "",
	[string]$Username = "")

	$path = (resolve-path $file)

	$filename = $file.Name
	$content = [IO.File]::readalltext($path.Path)

	$content = $content -replace "`t", "\t"
	$content = $content -replace "`r", "\r"
	$content = $content -replace "`n", "\n"
	$content = $content -replace """", "\"""

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

	$body = "{
		""description"": """ + $Description + """,
		""public"": true,
		""files"": {
			""" + $filename + """: {
				""content"": """ + $content + """
			}
		}
	}"

	$bytes = [text.encoding]::Default.getbytes($body)
	$request.ContentLength = $bytes.Length

	$stream = [io.stream]$request.GetRequestStream()
	$stream.Write($bytes,0,$bytes.Length)

	$response = $request.GetResponse()
	$responseStream = $response.GetResponseStream()
	$reader = New-Object system.io.streamreader -ArgumentList $responseStream
	$json = $reader.ReadToEnd()
	$reader.close()

	$result = convertfrom-json $json -Type PSObject

	$result.html_url
}
