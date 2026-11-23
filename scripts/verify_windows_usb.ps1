# Query the negotiated USB 2.0 speed through the immediate parent hub.
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$displayDevices = @(Get-PnpDevice -PresentOnly | Where-Object InstanceId -Like "USB\VID_303A&PID_2987*")
if ($displayDevices.Count -ne 1) { throw "Expected exactly one connected 303A:2987 device." }
$target = $displayDevices[0].InstanceId
$parent = (Get-PnpDeviceProperty -InstanceId $target -KeyName DEVPKEY_Device_Parent).Data
$address = (Get-PnpDeviceProperty -InstanceId $target -KeyName DEVPKEY_Device_Address).Data
if ($address -lt 1 -or $address -gt 255) { throw "Invalid USB hub port from PnP." }

Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public static class P4DisplayUsb
{
    private const uint IoctlGetConnectionInfoEx = (0x22u << 16) | (274u << 2);
    private static Guid hubGuid = new Guid("f18a0e88-c30c-11d0-8815-00a0c906bed8");

    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern uint CM_Get_Device_Interface_List_SizeW(out uint count, ref Guid guid,
        string deviceId, uint flags);

    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern uint CM_Get_Device_Interface_ListW(ref Guid guid, string deviceId,
        [Out] char[] names, uint count, uint flags);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, ExactSpelling = true)]
    private static extern SafeFileHandle CreateFileW(string path, uint access, uint share,
        IntPtr security, uint disposition, uint flags, IntPtr template);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool DeviceIoControl(SafeFileHandle handle, uint code, byte[] input,
        uint inputLength, [Out] byte[] output, uint outputLength, out uint returned, IntPtr overlapped);

    public static string Query(string parentId, uint port)
    {
        uint count;
        uint status = CM_Get_Device_Interface_List_SizeW(out count, ref hubGuid, parentId, 0);
        if (status != 0 || count <= 1)
            throw new InvalidOperationException("No present interface for the parent USB hub. CR=" + status);
        char[] names = new char[count];
        status = CM_Get_Device_Interface_ListW(ref hubGuid, parentId, names, count, 0);
        if (status != 0)
            throw new InvalidOperationException("Cannot read USB hub interface. CR=" + status);
        string[] paths = new string(names).Split(new[] {'\0'}, StringSplitOptions.RemoveEmptyEntries);
        if (paths.Length != 1)
            throw new InvalidOperationException("USB hub interface is ambiguous.");
        using (SafeFileHandle handle = CreateFileW(paths[0], 0xc0000000u, 3, IntPtr.Zero, 3, 0, IntPtr.Zero))
        {
            if (handle.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
            byte[] request = new byte[1024];
            BitConverter.GetBytes(port).CopyTo(request, 0);
            byte[] response = new byte[request.Length];
            uint returned;
            if (!DeviceIoControl(handle, IoctlGetConnectionInfoEx, request, (uint)request.Length,
                    response, (uint)response.Length, out returned, IntPtr.Zero))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            // ULONG port followed by the 18-byte USB_DEVICE_DESCRIPTOR, configuration and speed.
            if (returned < 24 || BitConverter.ToUInt32(response, 0) != port ||
                response[4] != 18 || response[5] != 1 ||
                BitConverter.ToUInt16(response, 12) != 0x303a || BitConverter.ToUInt16(response, 14) != 0x2987)
                throw new InvalidOperationException("Hub response does not describe the target 303A:2987.");
            string[] speeds = {"Low-Speed (1.5 Mbps)", "Full-Speed (12 Mbps)", "High-Speed (480 Mbps)"};
            int speed = response[23];
            if (speed >= speeds.Length) throw new InvalidOperationException("Unexpected USB speed " + speed);
            return String.Format("303A:2987 on hub port {0}: {1} (speed={2}, CurrentConfigurationValue={3})",
                port, speeds[speed], speed, response[22]);
        }
    }
}
'@

[P4DisplayUsb]::Query($parent, [uint32]$address)
