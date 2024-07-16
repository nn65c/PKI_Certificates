<#
.SYNOPSIS
Generates a Certificate Signing Request (CSR) for an End-entity.

.DESCRIPTION
This function generates a CSR for an End-entity with specified parameters,
including subject name, DNS names, IP addresses, key length, and more. The CSR
can be created in the LocalMachine or CurrentUser context.
If this is done on the computer that is going to use the cetificate, the 
private key never leaves the computer. The request is stored in:
cert:\<LocalMachine or CurrentUser\REQUEST
A CSR file in PEM format is stored from this function. This file must be sent 
to a CA that will sign and return a certificate file. This file must be 
imported into:
cert:\<LocalMachine or CurrentUser\My 
This operation will merge the request and private key into a valid certificate
on the local computer.

.PARAMETER Subject
The subject name for the CSR, usually a domain name. If not specified, the
current full hostname or NetBIOS name will be used.

.PARAMETER DnsName
The DNS names to be included in the Subject Alternative Name extension.
Defaults to the Subject, or both NetBIOS and full hostname if Subject is not
specified.

.PARAMETER IPAddress
IP addresses to be included in the Subject Alternative Name extension. Each
must be a valid IP address.

.PARAMETER EndEntityType
Type of end entity. Can be Server, Client, or ServerClient.

.PARAMETER FriendlyName
Friendly name for the certificate request. This is a Microsoft parameter, and
not part of the signed certificate. May be changed after certificate is 
signed. Defaults to "<EndEntityType>, <Subject>".

.PARAMETER KeyLength
Key length for the RSA key. Valid values are 1024, 2048, 3072, and 4096. The
default is 3072.

.PARAMETER Context
Reuest may be generated for CurrentUser or LocalMachine. Default is
LocalMachine and requires running as administrator.

.PARAMETER PrivateKeyExportable
Make private key exportable. This must be enabled if:
- Certificate is not going to be used on the computer the CSR is generated.
- Certificate is generated in CurrentUser context, and must be moved
  to LocalMachine context.

.PARAMETER Force
The function will check if there is already a CSR generated for the requested
subject. Checks both for CSR-file and Certificate store. 

.PARAMETER OutFile
CSR output filename. This will be in PEM, and correctly formatted as Ascii. 
The default Unicode encoding will not be accepted by CA for signing. Default
filename is <Subject>.csr in the current directory.

.EXAMPLE
New-CsrEndEntity

Generates a CSR with default settings. Must be run as administrator.
- Subject: Current computer full hostname or NetBIOS name.
- DnsName: Same as Subject, but will include both full hostname and NetBIOS
           name if they are different.
- EndEntityType: Server
- KeyLength: 3072
- PrivateKeyExportable: False
- Context: LocalMachine. 
- FriendlyName: "Server, <Subject>"
- OutFile: <Subject>.csr in current directory

.EXAMPLE
New-CsrEndEntity -Subject "w22server1.dom23.local" -DnsName "w22server1.dom23.local", "w22server1" -FriendlyName "Server, w22server1 PS" -KeyLength 3072 -IPAddress "192.168.17.238" -OutFile "server.csr" -Context CurrentUser

.EXAMPLE
$params = @{
    Subject              = "w22server1.dom23.local"
    DnsName              = @("w22server1.dom.local", "w22server1")
    IPAddress            = @("192.168.17.238")
    FriendlyName         = "Server, w22server.dom23.local PS"
    KeyLength            = 3072
    EndEntityType        = "Server"
    Context              = "LocalMachine"
    PrivateKeyExportable = $true
    Force                = $true
    OutFile              = "server.csr"
}

New-CsrEndEntity @params

.NOTES
Author: Frode Hansen
Date: 16.07.2024

Root CA needed for validation is included in the certificate chain in the 
signature. It may also be downloaded here:
https://nn65c.net/ca/fhrootca_v1.crt

This must be installed in "Trusted Root Certification Authorities" if script
signature is required.
#>
function New-CsrEndEntity {
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage = "The subject name for the CSR, usually a domain name. If not specified, the current full hostname or NetBIOS name will be used.")]
        [string]$Subject,

        [Parameter(HelpMessage = "The DNS names to be included in the Subject Alternative Name extension. Defaults to the Subject, or both NetBIOS and full hostname if Subject is not specified.")]
        [string[]]$DnsName,

        [Parameter(HelpMessage = "IP addresses to be included in the Subject Alternative Name extension. Each must be a valid IP address.")]
        [ValidateScript({
                foreach ($ip in $_) {
                    if (-not [System.Net.IPAddress]::TryParse($ip, [ref]$null)) {
                        throw "Invalid IP address: $ip"
                    }
                }
                $true
            })]
        [string[]]$IPAddress,

        [Parameter(HelpMessage = "Force the creation of a new CSR even if it already exists in 'Certificate store' and/or as file for the specified subject.")]
        [switch]$Force,

        [Parameter(HelpMessage = "Friendly name for the certificate request.")]
        [string]$FriendlyName,

        [Parameter(HelpMessage = "Key length for the RSA key. Valid values are 1024, 2048, 3072, and 4096.")]
        [ValidateSet(1024, 2048, 3072, 4096)]
        [int]$KeyLength = 3072,

        [Parameter(HelpMessage = "Type of end entity. Can be Server, Client, or ServerClient.")]
        [ValidateSet("Server", "Client", "ServerClient")]
        [string]$EndEntityType = "Server",

        [Parameter(HelpMessage = "Specifies the context in which to generate the key. Valid values are CurrentUser and LocalMachine. LocalMachine and requires running as administrator.")]
        [ValidateSet("CurrentUser", "LocalMachine")]
        [string]$Context = "LocalMachine",
        
        [Parameter(HelpMessage = "Make private key exportable.")]
        [switch]$PrivateKeyExportable,

        [Parameter(HelpMessage = "Filename for CSR output in PEM format.")]
        [string]$OutFile
    )

    # Check if running as administrator if LocalMachine context is specified
    if ($Context -eq "LocalMachine" -and -not (
            [System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole(
            [System.Security.Principal.WindowsBuiltInRole]::Administrator
        )) {
        throw "Must be running as administrator to use LocalMachine context."
    }
                
    # If Subject is not specified, use the current full hostname or NetBIOS name
    if (-not $PSBoundParameters.ContainsKey('Subject')) {
        $hostname = [System.Net.Dns]::GetHostName()
        $DnsName = @($hostname)
        $Subject = $hostname
        $fqdn = [System.Net.Dns]::GetHostEntry($hostname).HostName
        if ($hostname -ne $fqdn) { 
            $DnsName += $fqdn
            $Subject = $fqdn
        }
    }
    elseif (-not $PSBoundParameters.ContainsKey('DnsName')) {
        $DnsName = @($Subject)
    }          
    
    Write-Verbose "Subject: $Subject"
    
    # Set default OutFile if not provided
    if (-not $OutFile) {
        $OutFile = "$Subject.csr"
    }
    
    # If OutFile does not contain a directory separator, add the current directory
    if (-not ($OutFile -like "*\*")) {
        $OutFile = Join-Path -Path (Get-Location) -ChildPath $OutFile
    }
    
    # Check if the file already exists
    if (Test-Path -Path $OutFile) {
        if (-not $Force) {
            throw "The file '$OutFile' already exists."
        }
    } 
    
    # Check for existing requests with the same subject
    $existingCerts = Get-ChildItem -Path "cert:\$Context\REQUEST" -ErrorAction SilentlyContinue | Where-Object Subject -EQ "CN=$Subject" 
    if ($existingCerts.Count -gt 0) {
        if (-not $Force) {
            throw "CSR for subject '$Subject' already exists in the $Context store.`ncert:\$Context\REQUEST\$($existingCerts[0].Thumbprint)"
        }
    }
    
    # Create Private Key
    $PrivateKey = New-Object -ComObject X509Enrollment.CX509PrivateKey -Property @{
        ProviderName   = "Microsoft RSA SChannel Cryptographic Provider"
        MachineContext = ($Context -eq "LocalMachine") 
        Length         = $KeyLength
        KeySpec        = 1 
        KeyUsage       = [int][Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyEncipherment
    }
    
    if ($PrivateKeyExportable) {
        $PrivateKey.ExportPolicy = 1
    }
    
    $PrivateKey.Create()
    
    Write-Verbose "PrivateKeyExportable: $PrivateKeyExportable"
    
    # Create Subject Distinguished Name with CN=
    $SubjectDN = New-Object -ComObject X509Enrollment.CX500DistinguishedName
    $SubjectDN.Encode("CN=$Subject", 0x0)
    
    # Create SAN extension
    $SAN = New-Object -ComObject X509Enrollment.CX509ExtensionAlternativeNames
    $IANs = New-Object -ComObject X509Enrollment.CAlternativeNames
    
    foreach ($dns in $DnsName) {
        $IAN = New-Object -ComObject X509Enrollment.CAlternativeName
        $IAN.InitializeFromString(0x3, $dns) # 0x3 for DNS Name
        $IANs.Add($IAN)
    }

    Write-Verbose "Subject Alternative Name - DNS: $($DnsName -join ", ")"
    
    # Adding IP Addresses to SAN if provided and valid
    if ($IPAddress) {
        foreach ($ip in $IPAddress) {
            $ipBytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
            $ipBase64 = [Convert]::ToBase64String($ipBytes)
            $IAN_IP = New-Object -ComObject X509Enrollment.CAlternativeName
            $IAN_IP.InitializeFromRawData(0x8, 1, $ipBase64) # 0x8 is for IP address, 1 for base64 encoding
            $IANs.Add($IAN_IP)
        }
        Write-Verbose "Subject Alternative Name - IP: $($IPAddress -join ", ")"
    }
    
    $SAN.InitializeEncode($IANs)
    
    # Create Key Usage Extension
    $KeyUsage = New-Object -ComObject X509Enrollment.CX509ExtensionKeyUsage
    $KeyUsage.InitializeEncode(
        [int][Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature -bor
        [int][Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyEncipherment -bor
        [int][Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyAgreement
    )
    $KeyUsage.Critical = $true

    # Create Enhanced Key Usage Extension. Server, Client or both
    $EKU = New-Object -ComObject X509Enrollment.CX509ExtensionEnhancedKeyUsage
    $OIDs = New-Object -ComObject X509Enrollment.CObjectIDs
    
    switch ($EndEntityType) {
        "Server" {
            $netOid = New-Object Security.Cryptography.Oid "1.3.6.1.5.5.7.3.1"
            $OID = New-Object -ComObject X509Enrollment.CObjectID
            $OID.InitializeFromValue($netOid.Value)
            $OIDs.Add($OID)
        }
        "Client" {
            $netOid = New-Object Security.Cryptography.Oid "1.3.6.1.5.5.7.3.2"
            $OID = New-Object -ComObject X509Enrollment.CObjectID
            $OID.InitializeFromValue($netOid.Value)
            $OIDs.Add($OID)
        }
        "ServerClient" {
            foreach ($type in @("1.3.6.1.5.5.7.3.1", "1.3.6.1.5.5.7.3.2")) {
                $netOid = New-Object Security.Cryptography.Oid $type
                $OID = New-Object -ComObject X509Enrollment.CObjectID
                $OID.InitializeFromValue($netOid.Value)
                $OIDs.Add($OID)
            }
        }
    }
    
    Write-Verbose "EndEntityType: $EndEntityType"

    $EKU.InitializeEncode($OIDs)

    # Create basic constraints extension CA:False
    $basicConstraints = New-Object -ComObject X509Enrollment.CX509ExtensionBasicConstraints
    $basicConstraints.InitializeEncode($false, -1)

    # Create PKCS#10 certificate request
    $PKCS10 = New-Object -ComObject X509Enrollment.CX509CertificateRequestPkcs10
    
    if ($Context -eq "CurrentUser") {
        $PKCS10.InitializeFromPrivateKey(0x1, $PrivateKey, "") # 0x1 for CurrentUser
    }
    else {
        $PKCS10.InitializeFromPrivateKey(0x2, $PrivateKey, "") # 0x2 for LocalMachine
    }

    Write-Verbose "Context: $Context"

    $PKCS10.Subject = $SubjectDN
    $PKCS10.X509Extensions.Add($SAN)
    $PKCS10.X509Extensions.Add($EKU)
    $PKCS10.X509Extensions.Add($KeyUsage)
    $PKCS10.X509Extensions.Add($basicConstraints)

    # Set the hash algorithm to SHA-256
    $hashAlgorithmOid = New-Object Security.Cryptography.Oid "SHA256"
    $HashAlgorithm = New-Object -ComObject X509Enrollment.CObjectId
    $HashAlgorithm.InitializeFromValue($hashAlgorithmOid.Value)
    $PKCS10.HashAlgorithm = $HashAlgorithm

    $Request = New-Object -ComObject X509Enrollment.CX509Enrollment
    
    # "Friendly name" is a local property available in Windows. It is not part
    # of the signed certificate. It may be changed after signing. Set a
    # default if not specified.
    if (-not $FriendlyName) {
        $FriendlyName = "$EndEntityType, $Subject"   
    }
    
    $Request.CertificateFriendlyName = $FriendlyName

    Write-Verbose "Friendly name: $FriendlyName"
    
    $Request.InitializeFromRequest($PKCS10)

    # Create the Certificate Signing Request (CSR). This will be placed in 
    # cert:\<LocalMachine or CurrentUser>\REQUEST.  
    # Output in PEM format (0x3) for CA to sign. 
    $Request.CreateRequest(0x3) | Out-File $OutFile -Encoding Ascii

    Write-Verbose "OutFile: $OutFile"
}

# SIG # Begin signature block
# MIIlPwYJKoZIhvcNAQcCoIIlMDCCJSwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCADKINw80tjDaiV
# wSIddEYQiZ5MKn0OE5W6jtnGcfgcQaCCHmMwggViMIIDSqADAgECAhEA66J92+MD
# boa23xMQ+BS4oDANBgkqhkiG9w0BAQsFADBHMRQwEgYDVQQDDAtfRkggUm9vdCBD
# QTEOMAwGA1UECgwFbm42NWMxDzANBgNVBAQMBkhhbnNlbjEOMAwGA1UEKgwFRnJv
# ZGUwHhcNMjQwNzE1MTA1MjI0WhcNMjUwNzE1MTA1MjI0WjAbMRkwFwYDVQQDDBBf
# RkggQ29kZSBTaWduaW5nMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# 2Gk51+QwneNw74wWeFzCVSFjq2ydBFAXd9NDQFEkTksQTcXmQcstFewkG4qI5Jcm
# 8aCGr4uavgrgV2d0cl/nGp0nyNdVLLOg5BnMO+qvTKOS3i1n5avCAln/SwrOyAhO
# QwiKgHs0ZslcQZark/jpPN4ZR5BujLPG9JO4qr6LHtIq59tWTwmtmibsXXbE5D79
# /pBD7rUY6sE9x3cuXUrl+OhUok3SEhJLoPjIU2g93Q2CTrjpJgPzTT/EAFvMW4kE
# x95ZMvFkqoDIGStswu+6S4jKPwRjxanSCS7N8bPW0TVRLomVTXFxTQHUKeRLAjNG
# ZKlJkp5G3YwM4JJw+YY4so1dEWeJ3ruR2y6MT1usoVhxLfzBKcNHu1dg0uN6I/mx
# 1VtjNvlohBhoUoWaZdWcVVD3RnoLimcPaCWGl5xrOHVSrmId9z5pPe/dvoxkvwny
# egqpt9BykG48bHA+4rQ7STOQ3zFYSsIwXfU+WmyFXl/OsnQzWnhZoxfsLdA1EZZD
# EmQdRfE7OoDIx9znETZhnNXQ7omfKEeSDurFS56ArsGXi33rMiGPdiG90g6JpbaG
# qq2VOtBwGHJdePsy7vHpLg3YfwP4y+WUlx6iiURSeU7dln+qbwT3hZF2W/TWcLN7
# AspuC/0xELAPc3EIMRaRNY2o4kZTn43esRdAQRJHn68CAwEAAaN1MHMwDAYDVR0T
# AQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYD
# VR0OBBYEFC0MlweUmBo1r2JvHSAXDKJ2oIZtMB8GA1UdIwQYMBaAFD0XtwI4U1Zx
# lVD+m57slW84cvtbMA0GCSqGSIb3DQEBCwUAA4ICAQBVEl4h2el8FlDFRw8EB7Tf
# j35WQa54+lqsE35RRacXFD/ITEnl60ua3hfABZRKy9RUaomMRTLsGylmlSFpyTwm
# leW8Pc/TmgXFtRic5oEHC497qXle0ipL9mFFY3wVq9BOvMoDaqi1f+dAyl9tzfp9
# OQedZJg+p/Mw83bl/iicQitDxK+7Jssm2b/rl+epCxp+fTB7QtZjPv6cwVkSgagk
# hsZyWEJ17MPP6HGZk/jpwWt5pQ286QWABGkiozwG7D+HsZmcAOh7GVSAOfifx613
# 4esTi0QntZMRabtssFJ8176q0FMeojxkMSUJFZFNPm0CiD+Qhhmzo9+5In9Yvl4R
# Rq9y6Lzv83cwtlxB9nVV/F3vLBjJOMWJFaYJXdmYU+I8UIzzWe8GPXYnAVeABCud
# 0lt73ll62uHprsnFqgpu/lnRazVjI/2Vqh+YYiz+6BbMKpN2+mU9nHLlC1pQwN45
# r9gqyfGZy1Kv80miwdXJ/wMaNkbGy24FQpW1pTApcDcUd3C7T3BamIpGrddF5NaK
# ZIqpxoMlAmqnZ6bXgEhOXsQgQWe5Ez6UKHyqHKjomVZ2EMGAY7+BLB8jukRqj1jG
# XLD8/8U7xc26qmQiXsJStwb1PFokTewj1jzbApEPl4iy5sPV01FEJhIzvMAoiFCb
# 2LY4Ae0jnX9r97b5IwK0nzCCBY0wggR1oAMCAQICEA6bGI750C3n79tQ4ghAGFow
# DQYJKoZIhvcNAQEMBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0
# IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNl
# cnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIz
# NTk1OVowYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcG
# A1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3Rl
# ZCBSb290IEc0MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv+aQc2je
# u+RdSjwwIjBpM+zCpyUuySE98orYWcLhKac9WKt2ms2uexuEDcQwH/MbpDgW61bG
# l20dq7J58soR0uRf1gU8Ug9SH8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBE
# EC7fgvMHhOZ0O21x4i0MG+4g1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxbGrzryc/N
# rDRAX7F6Zu53yEioZldXn1RYjgwrt0+nMNlW7sp7XeOtyU9e5TXnMcvak17cjo+A
# 2raRmECQecN4x7axxLVqGDgDEI3Y1DekLgV9iPWCPhCRcKtVgkEy19sEcypukQF8
# IUzUvK4bA3VdeGbZOjFEmjNAvwjXWkmkwuapoGfdpCe8oU85tRFYF/ckXEaPZPfB
# aYh2mHY9WV1CdoeJl2l6SPDgohIbZpp0yt5LHucOY67m1O+SkjqePdwA5EUlibaa
# RBkrfsCUtNJhbesz2cXfSwQAzH0clcOP9yGyshG3u3/y1YxwLEFgqrFjGESVGnZi
# fvaAsPvoZKYz0YkH4b235kOkGLimdwHhD5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXe
# eqxfjT/JvNNBERJb5RBQ6zHFynIWIgnffEx1P2PsIV/EIFFrb7GrhotPwtZFX50g
# /KEexcCPorF+CiaZ9eRpL5gdLfXZqbId5RsCAwEAAaOCATowggE2MA8GA1UdEwEB
# /wQFMAMBAf8wHQYDVR0OBBYEFOzX44LScV1kTN8uZz/nupiuHA9PMB8GA1UdIwQY
# MBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5BggrBgEF
# BQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBD
# BggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0
# QXNzdXJlZElEUm9vdENBLmNydDBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3Js
# My5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMBEGA1Ud
# IAQKMAgwBgYEVR0gADANBgkqhkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22
# Ftf3v1cHvZqsoYcs7IVeqRq7IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv9P+Aufih
# 9/Jy3iS8UgPITtAq3votVs/59PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYD
# E3cnRNTnf+hZqPC/Lwum6fI0POz3A8eHqNJMQBk1RmppVLC4oVaO7KTVPeix3P0c
# 2PR3WlxUjG/voVA9/HYJaISfb8rbII01YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88n
# q2x2zm8jLfR+cWojayL/ErhULSd+2DrZ8LaHlv1b0VysGMNNn3O3AamfV6peKOK5
# lDCCBfAwggPYoAMCAQICFENGuXjb+hb6FJDRYGgX9bqrjCoNMA0GCSqGSIb3DQEB
# CwUAMEcxFDASBgNVBAMMC19GSCBSb290IENBMQ4wDAYDVQQKDAVubjY1YzEPMA0G
# A1UEBAwGSGFuc2VuMQ4wDAYDVQQqDAVGcm9kZTAeFw0yNDA3MTUxMDQ4MDVaFw0z
# NDA3MTMxMDQ4MDVaMEcxFDASBgNVBAMMC19GSCBSb290IENBMQ4wDAYDVQQKDAVu
# bjY1YzEPMA0GA1UEBAwGSGFuc2VuMQ4wDAYDVQQqDAVGcm9kZTCCAiIwDQYJKoZI
# hvcNAQEBBQADggIPADCCAgoCggIBAK3rB6FUmx5IzPVAT9JDtIn+/tCQs1kB9xHa
# C1X+ozQ8chU/DXBtYoAwl1Jr8lnAQqymm3ZTeuS9SWqp6vJy73KTa6YqWUvfFzML
# DbpRKJq+YsJxjzQpBDJXHlqhfIqaQAqXWgtxu9pKzUVGyeas6SxpR80tDNtLh5tG
# FIQjXAFB8rNEtd685AJefPGL7fIaRlj5zPQL3Xeetw+MYAg3RV1ccttcwYNyozVa
# Oc7UC7W5Pz3qXWsJLNqPaMSLAnbA0rA77kGFBydinCZDyi8O+rV9tX/bAxH3pwF2
# k/+fgqvA4NG8PcgJa9Ygy6zx6SI5fZC5hJhAqyr8IOINf6JCW3XIdxAdoUbIecKY
# jTTkHHkVyxMRaOhIWljY5nD6RcrlHU8HgFieoxY7opfE0X4aihHV/Tj44t4hbrsI
# Md4O2lVkjgdca32RRCuVRs53S1GGmHXGPE2NNlAXLDvria8lXccsDD31u7nK33xJ
# U/wJmX6rbcsA0SVMETZvqr0U1a4+1N0gsHL6dsX9MvUbySlPPQ7Ray3/VimKxqFy
# fhZXgqHUr5TOHcPT52hv7EwYSK2mg5WPFb1gMRRxrFz5SBjKU9NuPpVi1aKKpMHK
# 8DQa1FK64Ujs3pOGePkp88dSZ+rZiDkQeV8N0989zhud+NFNwVxnAgxBJ65txIoJ
# vJA+C3bnAgMBAAGjgdMwgdAwHwYDVR0jBBgwFoAUPRe3AjhTVnGVUP6bnuyVbzhy
# +1swDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAYYwMQYDVR0lBCowKAYI
# KwYBBQUHAwIGCCsGAQUFBwMDBggrBgEFBQcDCQYIKwYBBQUHAwEwOgYDVR0gBDMw
# MTAvBgkrBgEEAeA5AQEwIjAgBggrBgEFBQcCARYUaHR0cDovL25uNjVjLm5ldC9j
# cHMwHQYDVR0OBBYEFD0XtwI4U1ZxlVD+m57slW84cvtbMA0GCSqGSIb3DQEBCwUA
# A4ICAQCbNSS/uNwrm6CsFLToI1kApLiDxGj1iqa21D3mb1BiIa2k4d/TBfJwRODo
# HyMCwUInsbfKaIT/my/N6/D2ATLj8cY6iiTqVVOoIaOEf8cpXE2hMCS2N+9jtrHc
# rk7kzqKO8iohRhJ3i9vaOAWR5DLYB45vtrG5EkiAur7mF0ZPTtS4xxyUzsjRBMbi
# AmVdkhTcEmwVx28m7PHnzuUrFAAmhXY1ELwtHyzBo/3XndNjOvL8hmXml95HCQQb
# hOXyCJTDdOypgIB7HtwYrH8TrB4UxGJGdw9g5YMkUeA14haXg3JX0tVzP2d/xcv+
# Vaaph61NEWFr9iPsKGP/CZC11Q/4E5crH91ZI/J5Y9CRoN5BmbOedsKu76ZPJ+lx
# ebzYw2bDiyNJ6KBFZln/0POKldB7DZF3xXx1VeEI4P77YsRvM66l610Doe5TgagP
# a33nmow0jFRjR8W9Z3LmdVCqF7KJv9cfMqXsJZfvZOTDzJtS/bu67EfhfG0YGvad
# Qrvtctm0k5znmEFPb7czstQ3qcrdKgXfhsktJGPTAvCahTXaqb8emn/WiOygpWKY
# y1ZQfRTYYZj1wkLSdzJYMP6l2sjX/f2B1v6uNVotwM2v8+b4i1+tgKRQQzIgFeQR
# qhtMntQaVC8noYL0Ha7BQgc4s6wIo3Bg9mdzgkma8pgjwHelTjCCBq4wggSWoAMC
# AQICEAc2N7ckVHzYR6z9KGYqXlswDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTIyMDMy
# MzAwMDAwMFoXDTM3MDMyMjIzNTk1OVowYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoT
# DkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJT
# QTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAMaGNQZJs8E9cklRVcclA8TykTepl1Gh1tKD0Z5Mom2gsMyD
# +Vr2EaFEFUJfpIjzaPp985yJC3+dH54PMx9QEwsmc5Zt+FeoAn39Q7SE2hHxc7Gz
# 7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupRPfDWVtTnKC3r07G1decfBmWNlCnT2exp
# 39mQh0YAe9tEQYncfGpXevA3eZ9drMvohGS0UvJ2R/dhgxndX7RUCyFobjchu0Cs
# X7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV5huowWR0QKfAcsW6Th+xtVhNef7Xj3OT
# rCw54qVI1vCwMROpVymWJy71h6aPTnYVVSZwmCZ/oBpHIEPjQ2OAe3VuJyWQmDo4
# EbP29p7mO1vsgd4iFNmCKseSv6De4z6ic/rnH1pslPJSlRErWHRAKKtzQ87fSqEc
# azjFKfPKqpZzQmiftkaznTqj1QPgv/CiPMpC3BhIfxQ0z9JMq++bPf4OuGQq+nUo
# JEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5K6jzRWC8I41Y99xh3pP+OcD5sjClTNfp
# mEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oiqMEmCPkUEBIDfV8ju2TjY+Cm4T72wnSy
# Px4JduyrXUZ14mCjWAkBKAAOhFTuzuldyF4wEr1GnrXTdrnSDmuZDNIztM2xAgMB
# AAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBS6FtltTYUv
# cyl2mi91jGogj57IbzAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwPTzAO
# BgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEE
# azBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYB
# BQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0
# ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcwCAYG
# Z4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAfVmOwJO2b5ip
# RCIBfmbW2CFC4bAYLhBNE88wU86/GPvHUF3iSyn7cIoNqilp/GnBzx0H6T5gyNgL
# 5Vxb122H+oQgJTQxZ822EpZvxFBMYh0MCIKoFr2pVs8Vc40BIiXOlWk/R3f7cnQU
# 1/+rT4osequFzUNf7WC2qk+RZp4snuCKrOX9jLxkJodskr2dfNBwCnzvqLx1T7pa
# 96kQsl3p/yhUifDVinF2ZdrM8HKjI/rAJ4JErpknG6skHibBt94q6/aesXmZgaNW
# hqsKRcnfxI2g55j7+6adcq/Ex8HBanHZxhOACcS2n82HhyS7T6NJuXdmkfFynOlL
# AlKnN36TU6w7HQhJD5TNOXrd/yVjmScsPT9rp/Fmw0HNT7ZAmyEhQNC3EyTN3B14
# OuSereU0cZLXJmvkOHOrpgFPvT87eK1MrfvElXvtCl8zOYdBeHo46Zzh3SP9HSjT
# x/no8Zhf+yvYfvJGnXUsHicsJttvFXseGYs2uJPU5vIXmVnKcPA3v5gA3yAWTyf7
# YGcWoWa63VXAOimGsJigK+2VQbc61RWYMbRiCQ8KvYHZE/6/pNHzV9m8BPqC3jLf
# BInwAM1dwvnQI38AC+R2AibZ8GV2QqYphwlHK+Z/GqSFD/yYlvZVVCsfgPrA8g4r
# 5db7qS9EFUrnEw4d2zc4GqEr9u3WfPwwggbCMIIEqqADAgECAhAFRK/zlJ0IOaa/
# 2z9f5WEWMA0GCSqGSIb3DQEBCwUAMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5E
# aWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0
# MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwHhcNMjMwNzE0MDAwMDAwWhcNMzQx
# MDEzMjM1OTU5WjBIMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIElu
# Yy4xIDAeBgNVBAMTF0RpZ2lDZXJ0IFRpbWVzdGFtcCAyMDIzMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAo1NFhx2DjlusPlSzI+DPn9fl0uddoQ4J3C9I
# o5d6OyqcZ9xiFVjBqZMRp82qsmrdECmKHmJjadNYnDVxvzqX65RQjxwg6seaOy+W
# ZuNp52n+W8PWKyAcwZeUtKVQgfLPywemMGjKg0La/H8JJJSkghraarrYO8pd3hkY
# hftF6g1hbJ3+cV7EBpo88MUueQ8bZlLjyNY+X9pD04T10Mf2SC1eRXWWdf7dEKEb
# g8G45lKVtUfXeCk5a+B4WZfjRCtK1ZXO7wgX6oJkTf8j48qG7rSkIWRw69XloNpj
# sy7pBe6q9iT1HbybHLK3X9/w7nZ9MZllR1WdSiQvrCuXvp/k/XtzPjLuUjT71Lvr
# 1KAsNJvj3m5kGQc3AZEPHLVRzapMZoOIaGK7vEEbeBlt5NkP4FhB+9ixLOFRr7St
# FQYU6mIIE9NpHnxkTZ0P387RXoyqq1AVybPKvNfEO2hEo6U7Qv1zfe7dCv95NBB+
# plwKWEwAPoVpdceDZNZ1zY8SdlalJPrXxGshuugfNJgvOuprAbD3+yqG7HtSOKmY
# CaFxsmxxrz64b5bV4RAT/mFHCoz+8LbH1cfebCTwv0KCyqBxPZySkwS0aXAnDU+3
# tTbRyV8IpHCj7ArxES5k4MsiK8rxKBMhSVF+BmbTO77665E42FEHypS34lCh8zrT
# ioPLQHsCAwEAAaOCAYswggGHMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAA
# MBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsG
# CWCGSAGG/WwHATAfBgNVHSMEGDAWgBS6FtltTYUvcyl2mi91jGogj57IbzAdBgNV
# HQ4EFgQUpbbvE+fvzdBkodVWqWUxo97V40kwWgYDVR0fBFMwUTBPoE2gS4ZJaHR0
# cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNI
# QTI1NlRpbWVTdGFtcGluZ0NBLmNybDCBkAYIKwYBBQUHAQEEgYMwgYAwJAYIKwYB
# BQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBYBggrBgEFBQcwAoZMaHR0
# cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5
# NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAgRrW
# 3qCptZgXvHCNT4o8aJzYJf/LLOTN6l0ikuyMIgKpuM+AqNnn48XtJoKKcS8Y3U62
# 3mzX4WCcK+3tPUiOuGu6fF29wmE3aEl3o+uQqhLXJ4Xzjh6S2sJAOJ9dyKAuJXgl
# nSoFeoQpmLZXeY/bJlYrsPOnvTcM2Jh2T1a5UsK2nTipgedtQVyMadG5K8TGe8+c
# +njikxp2oml101DkRBK+IA2eqUTQ+OVJdwhaIcW0z5iVGlS6ubzBaRm6zxbygzc0
# brBBJt3eWpdPM43UjXd9dUWhpVgmagNF3tlQtVCMr1a9TMXhRsUo063nQwBw3syY
# nhmJA+rUkTfvTVLzyWAhxFZH7doRS4wyw4jmWOK22z75X7BC1o/jF5HRqsBV44a/
# rCcsQdCaM0qoNtS5cpZ+l3k4SF/Kwtw9Mt911jZnWon49qfH5U81PAC9vpwqbHkB
# 3NpE5jreODsHXjlY9HxzMVWggBHLFAx+rrz+pOt5Zapo1iLKO+uagjVXKBbLafIy
# mrLS2Dq4sUaGa7oX/cR3bBVsrquvczroSUa31X/MtjjA2Owc9bahuEMs305MfR5o
# cMB3CtQC4Fxguyj/OOVSWtasFyIjTvTs0xf7UGv/B3cfcZdEQcm4RtNsMnxYL2dH
# ZeUbc7aZ+WssBkbvQR7w8F/g29mtkIBEr4AQQYoxggYyMIIGLgIBATBcMEcxFDAS
# BgNVBAMMC19GSCBSb290IENBMQ4wDAYDVQQKDAVubjY1YzEPMA0GA1UEBAwGSGFu
# c2VuMQ4wDAYDVQQqDAVGcm9kZQIRAOuifdvjA26Gtt8TEPgUuKAwDQYJYIZIAWUD
# BAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMx
# DAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkq
# hkiG9w0BCQQxIgQgIk0daoe/4ktpHXLkxe0l5LPMle5LRwSLoQP3Vo8VE14wDQYJ
# KoZIhvcNAQEBBQAEggIAp3/lpCNUM76uvMGKNcGWzUB4rbFd0TB/2M3+PXB0UdjX
# poUqj2TKYddEY7EFaWM6CIWxnskUQAStvFkswTKgg0h2bulv234ugNI+RjNuqJX3
# wVNgXxm1DSX7SkzNz9s64QGiTBObTo3xOgb901y0W0Xr9gbevVi+QnjdrTVZ4PuG
# HOT9azM6nwlaKdKWTUeUWXkift8cHxqeO3Y3K7A2JUfH1n3qZfFzRHauuDewKcgY
# Iv4nyHgmgaZ7x7Je4X0tABDTJO1pEUKI2Nm0O8KS1OznGwfqdho0X5BuaKYiOv0q
# 3tOVmdN5CCJqxB57aQ6yxeL40vNmMlMa0z5VIi/efumjhrUvM6+3oP8N6weeekKn
# En10Cbq6NXljHlHmMppQIUhNcEXS6TO7GEcEyzk3cedTRKJMUAyMzQohQoAW2++M
# bCEhign9AoAUTNDCl2Y3vkWvIIhdhGcJedZGh6oyjHKdQcVcQ28MhoMdFKaglfeX
# 5Nf3lPpXUEj1YHVGnmWJUbkxjLDTlwfsNzveV9ylzq8uoRfLCrGkzveb9ZkKl3XJ
# EpTBVlh9UHK+fJyZRYvzYmlmB7Wbkb9mo/+bN99Ev0FFBB80iwsTA7ZlTDQ7p8LR
# Fa7qnZzXwMdKoBdGFfIXW8U4zpTTnQyXYQ0GPvwLhtzrF193i9/WvDpzJQ8J42Oh
# ggMgMIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0
# ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhAFRK/zlJ0IOaa/
# 2z9f5WEWMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEH
# ATAcBgkqhkiG9w0BCQUxDxcNMjQwNzE2MTAyODU5WjAvBgkqhkiG9w0BCQQxIgQg
# Ul2EIDwZnDRLQrgTwgIVFnndPGpIFIrPbjfXpAk3wQwwDQYJKoZIhvcNAQEBBQAE
# ggIAGM6lA5rB+Pe6hi+8xbQJEWmt6AYLicgRbAWv7P6vfvuBMcBMJvZV8XZgJ8Bb
# E09tfBLTafDPR//epZqrkXYQ3d8OTPs5u5PV0Kbmj93wOYylU5W2ITO1rJvv1Q2K
# DwuMP1DhBRXxaXGS+zlUDZhNnfECNEak1OVawZvV9KCyqS+mqF3LiLCbJTX1d85f
# NJwNSfzW6l3UK4TwJCz+stPGsZnkuUFtHx7a6HNj5LdynFJMzvXBpWrt2P1ue0My
# +6CF8WpxC+CA6UNjr3eOZ/YG2Qu8xcLh3CIJ0K4ekDVK8K1kiPeJjATvVBqciHcK
# /oDEyP2FZm6TInHjfg/3CZThjEKrsCTXLopM4qRsGzYn+kzm+K/AhGSLoo9Buac/
# h9VBpWyGSWGy8ZIkQGvj0981ZbPOridgKX0OF6KwF1mUcHl8DpiDNXe0RX3HmBwK
# 6y+qk9Cp8G/p4N3Z1OjzI3xnUOqhI7Cdb0Z/zZybQRrCqduXOeC3W08+iUGzQUkS
# bwMblhHIG+iyXuxmuf4iRY8+OctcAFsY0sNNSgIN1BtMuY6xHTvol4XL5fxhg7SH
# c0gdyILjQVAcMDoedO/UyK7oPubfll38rP52y8KWA7A4g7c8pZqYyaUBympGHIuN
# Bs9Z06ZKkdM46g+hetq22zNq8oIMukPwT9setmVpH0cAdZo=
# SIG # End signature block
