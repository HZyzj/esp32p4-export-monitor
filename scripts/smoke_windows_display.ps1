$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$devices = @(Get-PnpDevice -PresentOnly | Where-Object InstanceId -Like "USB\VID_303A&PID_2987*")
if ($devices.Count -ne 1 -or $devices[0].Status -ne "OK") { throw "The ESP32-P4 display driver is not active." }
"USB display driver: $($devices[0].FriendlyName), status $($devices[0].Status)"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$screens = [Windows.Forms.Screen]::AllScreens
"Active screens: $($screens.Count)"
foreach ($screen in $screens) {
    "$($screen.DeviceName) $($screen.Bounds.Width)x$($screen.Bounds.Height) at $($screen.Bounds.X),$($screen.Bounds.Y) Primary=$($screen.Primary)"
}
$destination = @($screens | Where-Object { !$_.Primary -and $_.Bounds.Width -eq 1024 -and $_.Bounds.Height -eq 600 })
if ($screens.Count -ne 2 -or $destination.Count -ne 1) { throw "Could not uniquely identify the active 1024x600 extended screen." }
$primary = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$secondary = $destination[0].Bounds
$form = [Windows.Forms.Form]::new()
$form.Text = "ESP32-P4 USB Display Test"
$form.StartPosition = "Manual"
$form.Bounds = [Drawing.Rectangle]::new($primary.Left + 40, $primary.Top + 40, 600, 320)
$form.BackColor = [Drawing.Color]::MidnightBlue
$form.TopMost = $true
$label = [Windows.Forms.Label]::new()
$label.Dock = 'Fill'
$label.ForeColor = [Drawing.Color]::White
$label.Font = [Drawing.Font]::new('Segoe UI', 26, [Drawing.FontStyle]::Bold)
$label.TextAlign = 'MiddleCenter'
$form.Controls.Add($label)
$script:p4_moved = $false
$watch = [Diagnostics.Stopwatch]::StartNew()
$timer = [Windows.Forms.Timer]::new()
$timer.Interval = 120
$timer.Add_Tick({
    $seconds = $watch.Elapsed.TotalSeconds
    if (!$script:p4_moved -and $seconds -gt 2) {
        $form.Bounds = [Drawing.Rectangle]::new($secondary.Left + 18, $secondary.Top + 18,
            $secondary.Width - 36, $secondary.Height - 36)
        $script:p4_moved = $true
        $onScreen = [Windows.Forms.Screen]::FromHandle($form.Handle).DeviceName
        $script:p4_move_message = "Test window moved to $onScreen at $($form.Location.X),$($form.Location.Y)"
    }
    $label.Text = "ESP32-P4 USB Display`r`n1024 x 600`r`n{0:0.0} s" -f $seconds
    if ($seconds -ge 30) { $form.Close() }
})
try {
    $timer.Start()
    [Windows.Forms.Application]::Run($form)
} finally {
    $timer.Stop()
    $timer.Dispose()
    $form.Dispose()
}
if (!$script:p4_moved) { throw "The test window closed before moving." }
$script:p4_move_message
"Test window completed after $([Math]::Round($watch.Elapsed.TotalSeconds, 1)) seconds."
