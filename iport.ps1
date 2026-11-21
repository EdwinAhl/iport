
param(
    [Parameter(Mandatory, Position=0)]
    [string]$InputValue,

    [Parameter(Position=1)]
    [string]$SecondValue
)

# ==========================================
# IPv4 address conversion
# ==========================================

function ConvertTo-UInt32IP($ip) {
    $bytes = ([System.Net.IPAddress]::Parse($ip)).GetAddressBytes()

    if ($bytes.Length -ne 4) {
        throw "Only IPv4 addresses are supported."
    }

    [uint64]$result = 0
    foreach ($byte in $bytes) {
        $result = ($result * 256) + $byte
    }

    return $result
}

function ConvertFrom-UInt32IP([uint64]$number) {
    $a = ($number -shr 24) -band 255
    $b = ($number -shr 16) -band 255
    $c = ($number -shr 8) -band 255
    $d = $number -band 255

    return "$a.$b.$c.$d"
}

# ==========================================
# Port-to-service lookup
# ==========================================

function Get-PortService([int]$Port) {

    if ($Port -lt 0 -or $Port -gt 65535) {
        throw "Port must be between 0 and 65535."
    }

    $servicesFile = "$env:windir\System32\drivers\etc\services"

    $results = @()

    # Read Windows services database
    if (Test-Path $servicesFile) {

        foreach ($line in Get-Content $servicesFile) {

            # Remove comments
            $line = ($line -split '#')[0].Trim()

            if ($line -match '^\s*(\S+)\s+(\d+)/(tcp|udp)\b') {

                $service = $Matches[1]
                $servicePort = [int]$Matches[2]
                $protocol = $Matches[3].ToUpperInvariant()

                if ($servicePort -eq $Port) {
                    $results += [PSCustomObject]@{
                        Service  = $service
                        Protocol = $protocol
                    }
                }
            }
        }
    }

    if ($results.Count -eq 0) {
        Write-Host "`nNo registered service found for port $Port." -ForegroundColor Red
        return
    }

    Write-Host "`nPort:    " -NoNewline
    Write-Host $Port -ForegroundColor Magenta

    # Group protocols by service so each service is displayed only once.
    foreach ($serviceGroup in ($results | Group-Object Service)) {

        $protocols = @(
            $serviceGroup.Group |
                Select-Object -ExpandProperty Protocol -Unique
        ) -join "/"

        Write-Host "Service: " -NoNewline
        Write-Host $serviceGroup.Name.ToUpperInvariant() -ForegroundColor Magenta

        Write-Host "Protocol:" -NoNewline
        Write-Host " $protocols" -ForegroundColor Magenta
    }

    Write-Host ""
}

# ==========================================
# Detect port lookup
# ==========================================

if (-not $SecondValue -and $InputValue -match '^\d+$') {

    Get-PortService -Port ([int]$InputValue)
    return
}

# ==========================================
# IP calculator
# ==========================================

# Case 0: IP address + subnet mask
if ($SecondValue) {

    $ip = $InputValue
    $maskInt = ConvertTo-UInt32IP $SecondValue

    [uint64]$inverse = 4294967295 -bxor $maskInt

    if (($inverse -band ($inverse + 1)) -ne 0) {
        throw "Invalid subnet mask: bits must be contiguous."
    }

    $prefix = 0
    $temp = $maskInt

    while ($temp -gt 0) {
        $prefix++
        $temp = $temp -band ($temp - 1)
    }

    $ipInt = ConvertTo-UInt32IP $ip
}

# Case 1: CIDR only, e.g. /29
elseif ($InputValue -match '^/(\d{1,2})$') {

    $prefix = [int]$Matches[1]

    if ($prefix -gt 32) {
        throw "Prefix must be between /0 and /32."
    }
}

# Case 2: IP address with CIDR
elseif ($InputValue -match '^(.+)/(\d{1,2})$') {

    $ip = $Matches[1]
    $prefix = [int]$Matches[2]

    if ($prefix -gt 32) {
        throw "Prefix must be between /0 and /32."
    }

    $ipInt = ConvertTo-UInt32IP $ip
}

# Case 3: Subnet mask or IPv4 address 
elseif ($InputValue -match '^\d{1,3}(\.\d{1,3}){3}$') {
    $inputInt = ConvertTo-UInt32IP $InputValue
    [uint64]$inverse = 4294967295 -bxor $inputInt

    # A valid subnet mask has contiguous leading 1 bits (and trailing 0 bits).
    if (($inverse -band ($inverse + 1)) -eq 0) {
        $maskInt = $inputInt
        $prefix = 0
        $temp = $maskInt

        while ($temp -gt 0) {
            $prefix++
            $temp = $temp -band ($temp - 1)
        }
    }
    else {
        # Not a valid subnet mask: treat it as an IP with the default /24.
        $ip = $InputValue
        $prefix = 24
        $ipInt = $inputInt
    }
}
else {
    throw "Invalid input. Use an IPv4 address, subnet mask, CIDR prefix, or port number."
}

# ==========================================
# Calculate subnet mask and wildcard
# ==========================================

[uint64]$maskInt = if ($prefix -eq 0) {
    0
}
else {
    ([uint32]::MaxValue -shl (32 - $prefix)) -band [uint32]::MaxValue
}

[uint64]$wildcardInt = 4294967295 -bxor $maskInt

$mask = ConvertFrom-UInt32IP $maskInt
$wildcard = ConvertFrom-UInt32IP $wildcardInt

# ==========================================
# Output subnet information
# ==========================================

$subnetColor = "Cyan"

Write-Host "`nCIDR:         " -NoNewline
Write-Host "/$prefix" -ForegroundColor $subnetColor

Write-Host "Subnet mask:  " -NoNewline
Write-Host $mask -ForegroundColor $subnetColor

Write-Host "Wildcard:     " -NoNewline
Write-Host $wildcard -ForegroundColor $subnetColor

# If no IP was provided, stop here
if (-not $ip) {
    Write-Host ""
    return
}

# ==========================================
# Calculate and output network and host information
# ==========================================

$network = $ipInt -band $maskInt
$broadcast = $network -bor $wildcardInt

$ipColor = "Yellow"
$hostColor = "Green"

Write-Host "IP address:   " -NoNewline
Write-Host $ip -ForegroundColor $ipColor

if ($prefix -le 30) {

    Write-Host "Network:      " -NoNewline
    Write-Host (ConvertFrom-UInt32IP $network) -ForegroundColor $ipColor

    Write-Host "Broadcast:    " -NoNewline
    Write-Host (ConvertFrom-UInt32IP $broadcast) -ForegroundColor $ipColor

    Write-Host "Addresses:    " -NoNewline
    Write-Host ([math]::Pow(2, 32 - $prefix)) -ForegroundColor $ipColor

    Write-Host "First host:   " -NoNewline
    Write-Host (ConvertFrom-UInt32IP ($network + 1)) -ForegroundColor $hostColor

    Write-Host "Last host:    " -NoNewline
    Write-Host (ConvertFrom-UInt32IP ($broadcast - 1)) -ForegroundColor $hostColor

    Write-Host "Usable hosts: " -NoNewline
    Write-Host ([math]::Pow(2, 32 - $prefix) - 2) -ForegroundColor $hostColor
}
elseif ($prefix -eq 31) {

    Write-Host "Usable hosts: " -NoNewline
    Write-Host "2 (point-to-point)" -ForegroundColor $hostColor
}
else {

    Write-Host "Usable hosts: " -NoNewline
    Write-Host "1 (host route)" -ForegroundColor $hostColor
}

Write-Host ""
