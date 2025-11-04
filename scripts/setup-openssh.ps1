# Enable logging
Start-Transcript -Path C:\WindowsAzure\Logs\openssh-setup.log -Append

Write-Output "=== Starting OpenSSH Server Installation ==="
Write-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Install OpenSSH Server capability
Write-Output "Installing OpenSSH.Server capability..."
try {
    $result = Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Write-Output "OpenSSH Server installation result: $($result.RestartNeeded)"
} catch {
    Write-Output "ERROR installing OpenSSH: $_"
    exit 1
}

# Wait for installation to complete
Start-Sleep -Seconds 5

# Start the sshd service
Write-Output "Starting sshd service..."
try {
    Start-Service sshd
    Write-Output "sshd service started successfully"
} catch {
    Write-Output "ERROR starting sshd: $_"
}

# Set sshd service to start automatically
Write-Output "Configuring sshd to start automatically..."
Set-Service -Name sshd -StartupType 'Automatic'

# Verify firewall rule exists
Write-Output "Checking firewall rules..."
$fwRule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
if (!$fwRule) {
    Write-Output "Creating firewall rule for OpenSSH Server..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
} else {
    Write-Output "Firewall rule already exists"
}

# Configure OpenSSH for password authentication
Write-Output "Configuring sshd_config..."
$sshdConfigPath = "C:\ProgramData\ssh\sshd_config"

# Wait for sshd_config to be created
$attempts = 0
while (!(Test-Path $sshdConfigPath) -and $attempts -lt 10) {
    Write-Output "Waiting for sshd_config to be created... (attempt $attempts)"
    Start-Sleep -Seconds 2
    $attempts++
}

if (Test-Path $sshdConfigPath) {
    Write-Output "Modifying sshd_config..."
    $config = Get-Content $sshdConfigPath
    
    # Enable password authentication
    $config = $config -replace '^#?PasswordAuthentication.*', 'PasswordAuthentication yes'
    
    # Enable pubkey authentication
    $config = $config -replace '^#?PubkeyAuthentication.*', 'PubkeyAuthentication yes'
    
    # Save configuration
    $config | Set-Content $sshdConfigPath -Force
    Write-Output "sshd_config updated successfully"
    
    # Restart sshd to apply changes
    Write-Output "Restarting sshd service..."
    Restart-Service sshd -Force
    Write-Output "sshd service restarted"
} else {
    Write-Output "WARNING: sshd_config not found after waiting"
}

# Configure default shell to PowerShell
Write-Output "Configuring default shell..."
try {
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force -ErrorAction SilentlyContinue
    Write-Output "Default shell configured to PowerShell"
} catch {
    Write-Output "Note: Could not set default shell (may already be set)"
}

# Configure DNS suffix search list
Write-Output "Configuring DNS suffix search list..."
try {
    Set-DnsClientGlobalSetting -SuffixSearchList @("hpevme.local") -ErrorAction Stop
    Write-Output "DNS suffix configured successfully"
} catch {
    Write-Output "Note: DNS suffix configuration may have failed: $_"
}

# Flush DNS cache
Write-Output "Flushing DNS cache..."
Clear-DnsClientCache
ipconfig /flushdns | Out-Null

# Enable ICMP (ping)
Write-Output "Enabling ICMP Echo Request..."
try {
    Set-NetFirewallRule -DisplayName 'File and Printer Sharing (Echo Request - ICMPv4-In)' -Enabled True -Profile Any -ErrorAction Stop
    Write-Output "ICMP enabled successfully"
} catch {
    Write-Output "Note: ICMP configuration may have failed: $_"
}

# Verify sshd is running
Write-Output "Verifying sshd service status..."
$sshdStatus = Get-Service sshd
Write-Output "sshd Status: $($sshdStatus.Status)"
Write-Output "sshd StartType: $($sshdStatus.StartType)"

# Test SSH port
Write-Output "Testing SSH port..."
$tcpTest = Test-NetConnection -ComputerName localhost -Port 22 -WarningAction SilentlyContinue
Write-Output "SSH Port 22 Open: $($tcpTest.TcpTestSucceeded)"

Write-Output "=== OpenSSH Server Installation Completed ==="
Write-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Stop-Transcript
