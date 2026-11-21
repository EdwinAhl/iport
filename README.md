# iport

**iport** is a PowerShell utility for IPv4 subnet calculations and port-to-service lookups.

```powershell
iport 192.168.1.10/24

CIDR:         /24
Subnet mask:  255.255.255.0
Wildcard:     0.0.0.255
IP address:   192.168.1.10
Network:      192.168.1.0
Broadcast:    192.168.1.255
Addresses:    256
First host:   192.168.1.1
Last host:    192.168.1.254
Usable hosts: 254
```

```powershell
iport 179

Port:    179
Service: BGP
Protocol: TCP
```

## Features

- IPv4 subnet calculations using CIDR notation or subnet masks.
- Calculate network address, broadcast address, wildcard mask, and usable host range.
- Port-to-service lookup using the Windows services database.
- No external dependencies required.

## Usage

### IPv4 calculations

You can provide an IPv4 address with CIDR notation:

```powershell
iport 192.168.1.10/24
```

Or provide an IP address and subnet mask separately:

```powershell
iport 192.168.1.10 255.255.255.0
```

You can also provide only a CIDR prefix or subnet mask:

```powershell
iport /24
iport 255.255.255.0
```

A standalone IPv4 address defaults to `/24`:

```powershell
iport 192.168.1.10
```

### Port-to-service lookup

Provide a port number to look up its registered service and protocol:

```powershell
iport 179
```

## Installation

iport can be installed manually and added to your Windows PATH, allowing you to execute it from any directory.

### 1. Download iport

Download or clone this repository.


### 2. Move `iport.ps1` and `iport.cmd` to your folder of choice

`iport.cmd` is a wrapper that allows you to execute the PowerShell script using the shorter `iport` command.

### 3. Add iport to PATH

1. Open the Windows Start menu.
2. Search for **Edit environment variables for your account**.
3. Select **Path** under User variables.
4. Click **Edit**, then **New**.
5. Add the iport installation directory:
6. Click **Ok** so save the changes.

### 4. Execution policy
If Windows blocks the script because it isn't digitally signed, run PowerShell as your normal user and execute:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```
## Requirements

- Windows PowerShell

Port lookups use the Windows services database located at:

```text
C:\Windows\System32\drivers\etc\services
```

## License

See the [LICENSE](LICENSE) file for licensing terms.