# =============================================================================
# Velvet - .NET NGEN Pre-compilation Optimization Script (ngen.ps1)
# =============================================================================

# Start .NET Framework background optimization scheduled tasks
Get-ScheduledTask -TaskPath "\Microsoft\Windows\.NET Framework\" -ErrorAction SilentlyContinue | Start-ScheduledTask -ErrorAction SilentlyContinue

# Add .NET runtime directory to PATH
$env:PATH = [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()

# Generate native images for all loaded assemblies in current AppDomain
[AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
    $path = $_.Location
    if ($path) { 
        $name = Split-Path $path -Leaf
        Write-Host "Running ngen on '$name'" -ForegroundColor DarkGray
        ngen.exe install $path /nologo 2>$null
    }
}
exit 0
