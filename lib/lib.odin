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
		ReturnLength: ^u32
	) -> int ---

	NtDuplicateObject :: proc(
	   	SourceProcessHandle, SourceHandle: win.HANDLE,
	   	TargetProcressHandle: win.HANDLE = nil, TargetHandle: ^win.HANDLE = nil,
		DesiredAcces: DesiredAccess,
		HandleAttributes, Options: win.ULONG,
	) -> int ---
}

DesiredAccess :: enum win.DWORD {
	NONE				= 0,
	
	DELETE				= 0x00010000,
	READ_CONTROL		= 0x00020000,
	SYNCHRONIZE			= 0x00100000,
	WRITE_DAC			= 0x00040000,
	WRITE_OWNER 		= 0x00080000,

	PROCESS_ALL_ACCESS 	= 0x000F0000 | 0x00100000 | 0xFFFF,

	EVENT_ALL_ACCESS	= 0x1F0003,
	EVENT_MODIFY_STATE	= 0x0002,
}

PUBLIC_OBJECT_BASIC_INFORMATION :: struct {
	Attributes: win.ULONG,
	GrantedAcces: win.DesiredAccess,
	HandleCount, PointerCount: win.ULONG,
	Reserved: win.ULONG
}

PUBLIC_OBJECT_TYPE_INFORMATION :: struct {
	TypeName: win.UNICODE_STRING,
	Reserver: win.ULONG
}

SystemExtendedHandleInformation :: 64

ObjectInformationClass :: enum {
	OBJECT_BASIC_INFORMATION = 0,
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
    Handles: [1]SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX
}
