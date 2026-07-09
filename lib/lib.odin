#+build windows
package RobloxMultiInstance_Windows_Lib

import win "core:sys/windows"
foreign import ntdll_lib "system:ntdll.lib"

@(default_calling_convention="system")
foreign ntdll_lib {
	NtQuerySystemInformation :: proc(
        SystemInformationClass: int,
        SystemInformation: rawptr,
        SystemInformationLength: u32,
        ReturnLength: ^u32,
    ) -> int ---

	NtQueryObject :: proc(
		Handle: win.HANDLE,
		ObjectInformationClass: ObjectInformationClass,
		ObjectInformation: win.PVOID,
		ObjectInformationLength: win.ULONG,
		ReturnLength: ^u32,
	) -> int ---
}

DesiredAccess :: enum win.DWORD {
	NONE				= 0,

	DELETE				= 0x00010000,

	PROCESS_ALL_ACCESS 	= 0x000F0000 | 0x00100000 | 0xFFFF,
}

PUBLIC_OBJECT_TYPE_INFORMATION :: struct {
	TypeName: win.UNICODE_STRING,
	Reserver: win.ULONG,
}

SystemExtendedHandleInformation :: 64

ObjectInformationClass :: enum {
	OBJECT_NAME_INFORMATION  = 1,
	OBJECT_TYPE_INFORMATION  = 2,
}

PUBLIC_OBJECT_NAME_INFORMATION :: struct {
    Name: win.UNICODE_STRING,
}

SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX :: struct {
    Object: rawptr,
    UniqueProcessId: win.ULONG_PTR,
    HandleValue: win.ULONG_PTR,
    GrantedAccess: u32,
    CreatorBackTraceIndex: u16,
    ObjectTypeIndex: u16,
    HandleAttributes: u32,
    Reserved: u32,
}

SYSTEM_HANDLE_INFORMATION_EX :: struct {
    NumberOfHandles: win.ULONG_PTR,
    Reserved: win.ULONG_PTR,
    Handles: [1]SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX,
}
