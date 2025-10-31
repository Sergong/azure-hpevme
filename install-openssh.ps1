# Install OpenSSH Server
Write-Output "Installing OpenSSH Server..."
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start the sshd service
Write-Output "Starting sshd service..."
Start-Service sshd

# Set sshd service to start automatically
Write-Output "Setting sshd to start automatically..."
Set-Service -Name sshd -StartupType 'Automatic'

# Configure firewall rule
Write-Output "Configuring firewall..."
New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue

# Configure sshd_config
Write-Output "Configuring sshd_config..."
$sshdConfigPath = "C:\ProgramData\ssh\sshd_config"
if (Test-Path $sshdConfigPath) {
    $config = Get-Content $sshdConfigPath
    $config = $config -replace '^#?PasswordAuthentication.*', 'PasswordAuthentication yes'
    $config = $config -replace '^#?PubkeyAuthentication.*', 'PubkeyAuthentication yes'
    $config | Set-Content $sshdConfigPath
    Restart-Service sshd
}

# Set default shell
Write-Output "Setting default shell..."
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force

Write-Output "OpenSSH Server installation completed successfully!"
