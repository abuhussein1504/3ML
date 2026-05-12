# Fix Flutter JDK and JAVA_HOME
$jdkPath = "C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"

if (Test-Path $jdkPath) {
    Write-Host "Found JDK at $jdkPath" -ForegroundColor Green
    
    # 1. Update Flutter Config
    Write-Host "Updating Flutter config..."
    flutter config --jdk-dir $jdkPath
    
    # 2. Update User JAVA_HOME
    Write-Host "Updating JAVA_HOME environment variable..."
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkPath, "User")
    $env:JAVA_HOME = $jdkPath
    
    Write-Host "Fix applied successfully!" -ForegroundColor Green
    Write-Host "Please RESTART your terminal and run 'flutter run' again." -ForegroundColor Yellow
} else {
    Write-Host "Error: Could not find JDK at $jdkPath" -ForegroundColor Red
    Write-Host "Checking for other JDKs in C:\Program Files\Eclipse Adoptium..."
    Get-ChildItem "C:\Program Files\Eclipse Adoptium"
}
