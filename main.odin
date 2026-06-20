package RobloxMultiInstance

import "core:fmt"
import "core:strings"
import win "core:sys/windows"
import "lib"
import "core:unicode/utf16"
import "core:unicode/utf8"
import "core:time"
import "core:terminal/ansi"

get_process_name :: proc(szExeFile: ^[win.MAX_PATH]win.WCHAR, allocator := context.allocator) -> string {
    n := 0
    for v in szExeFile {
        if v == 0 do break
        n += 1
    }

    utf16Slice := szExeFile[:n]
    runes, err := utf16.string_to_runes(string16(utf16Slice))
    if err != nil do return ""
    defer delete(runes)

    return utf8.runes_to_string(runes, allocator)
}   

read_unicode_string :: proc(us: win.UNICODE_STRING, allocator := context.allocator) -> string {
    if us.Buffer == nil || us.Length == 0 do return ""
    
    length_wchars := us.Length / 2
    slice := ([^]win.WCHAR)(us.Buffer)[:length_wchars]
    
    runes, err := utf16.string_to_runes(string16(slice))
    if err != nil do return ""
    defer delete(runes)
    
    return utf8.runes_to_string(runes, allocator)
}

get_process_handles :: proc(pid: u32, allocator := context.allocator) -> []lib.SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX {
    buffer_size: u32 = 0x10000
    
    for {
    	u64_count := (buffer_size + 7) / 8
        buffer := make([]u64, u64_count)
    	
        status := lib.NtQuerySystemInformation(
            lib.SystemExtendedHandleInformation,
            raw_data(buffer),
            buffer_size,
            &buffer_size,
        )
        
        if status == 0 {
            info := cast(^lib.SYSTEM_HANDLE_INFORMATION_EX)(raw_data(buffer))
            result := make([dynamic]lib.SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX, allocator)
            entries_ptr := cast([^]lib.SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX)(&info.Handles[0])
            
            for handle in entries_ptr[:info.NumberOfHandles] {
                if u32(handle.UniqueProcessId) == pid {
                    append(&result, handle)
                }
            }

            delete(buffer)
            return result[:]
        }

        delete(buffer)
        if status != 0xC0000004 {
            fmt.printfln("get_process_handles erro: %x", status)
            return nil
        }
    }
}

try_close_roblox_singleton :: proc(pid: u32) -> bool {
    process := win.OpenProcess(u32(lib.DesiredAccess.PROCESS_ALL_ACCESS), false, pid)
    if process == nil do return false
    
    defer win.CloseHandle(process)
    
    handles := get_process_handles(pid, context.temp_allocator)
    
    for handle in handles {
        target_handle := win.HANDLE(uintptr(handle.HandleValue))
        local_handle: win.HANDLE
        
        dup_success := win.DuplicateHandle(
            process,
            target_handle,
            win.GetCurrentProcess(),
            &local_handle,
            0,
            false,
            win.DUPLICATE_SAME_ACCESS,
        )
        if !dup_success do continue
        defer win.CloseHandle(local_handle)
        
        size: u32 = 0
        lib.NtQueryObject(local_handle, .OBJECT_TYPE_INFORMATION, nil, 0, &size)
        if size == 0 do continue

        u64_count := (size + 7) / 8
        type_buffer := make([]u64, u64_count, context.temp_allocator)
        if lib.NtQueryObject(local_handle, .OBJECT_TYPE_INFORMATION, raw_data(type_buffer), size, &size) != 0 do continue
        
        type_info := cast(^lib.PUBLIC_OBJECT_TYPE_INFORMATION)(raw_data(type_buffer))
        type_name := read_unicode_string(type_info.TypeName, context.temp_allocator)
        
        if type_name != "Event" && type_name != "Mutant" do continue
        
        size = 0
        lib.NtQueryObject(local_handle, cast(lib.ObjectInformationClass)1, nil, 0, &size)
        if size == 0 do continue
        
        u64_count = (size + 7) / 8
        name_buffer := make([]u64, u64_count, context.temp_allocator)
        if lib.NtQueryObject(local_handle, cast(lib.ObjectInformationClass)1, raw_data(name_buffer), size, &size) != 0 do continue
        
        name_info := cast(^lib.PUBLIC_OBJECT_NAME_INFORMATION)(raw_data(name_buffer))
        obj_name := read_unicode_string(name_info.Name, context.temp_allocator)
        
        if strings.contains(obj_name, "ROBLOX_singletonEvent") {
            dummy_handle: win.HANDLE
            
            win.DuplicateHandle(process, target_handle, win.GetCurrentProcess(), &dummy_handle, 0, false, 1)
            win.CloseHandle(dummy_handle)
            
            fmt.printfln(ansi.CSI + ansi.FG_BRIGHT_RED + ansi.SGR + "[-] Deleted Singleton Event." + ansi.CSI + ansi.RESET + ansi.SGR)
            return true
        }
    }
    
    return false
}

monitor_loop :: proc() {
    processed_pids := make(map[u32]bool)
    defer delete(processed_pids)

    fmt.println(ansi.CSI + ansi.FG_YELLOW + ansi.SGR + "Waiting for Roblox instances." + ansi.CSI + ansi.RESET + ansi.SGR)

    n := 0
    for {
        snapshot := win.CreateToolhelp32Snapshot(win.TH32CS_SNAPPROCESS, 0)
        if snapshot == win.INVALID_HANDLE_VALUE {
            time.sleep(100 * time.Millisecond)
            continue
        }

        buffer := win.PROCESSENTRY32W{}
        buffer.dwSize = size_of(win.PROCESSENTRY32W)

        active_pids := make(map[u32]bool, 0, context.temp_allocator)

        if win.Process32FirstW(snapshot, &buffer) {
            for {
                exe_name := get_process_name(&buffer.szExeFile, context.temp_allocator)
                
                if exe_name == "RobloxPlayerBeta.exe" {
                    pid := buffer.th32ProcessID
                    active_pids[pid] = true

                    if !processed_pids[pid] {
                        if try_close_roblox_singleton(pid) {
                        	processed_pids[pid] = true
                         	n = 0
                        }
                        if n < 3 {
                        	n+=1
                        	fmt.println(ansi.CSI + ansi.FG_CYAN + ansi.SGR + "[*] New instance detected. Applying patch." + ansi.CSI + ansi.RESET + ansi.SGR)
                        }
                    }

                }

                if !win.Process32NextW(snapshot, &buffer) do break
            }
        }
        win.CloseHandle(snapshot)

        for pid in processed_pids {
            if !active_pids[pid] {
                delete_key(&processed_pids, pid)
            }
        }

        free_all(context.temp_allocator)

        // Um tempinho de espera para não consumir muito da CPU
        time.sleep(700 * time.Millisecond)
    }
}

main :: proc() {
    monitor_loop()
}