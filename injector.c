#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: injector.exe <dll_path> <process_name>\n");
        return 1;
    }

    const char *dll_path = argv[1];
    const char *proc_name = argv[2];

    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "CreateToolhelp32Snapshot failed\n");
        return 1;
    }

    PROCESSENTRY32W entry;
    entry.dwSize = sizeof(entry);
    DWORD pid = 0;

    if (Process32FirstW(snapshot, &entry)) {
        do {
            char exe_name[256];
            WideCharToMultiByte(CP_ACP, 0, entry.szExeFile, -1, exe_name, sizeof(exe_name), NULL, NULL);
            if (strstr(exe_name, proc_name)) {
                pid = entry.th32ProcessID;
                break;
            }
        } while (Process32NextW(snapshot, &entry));
    }
    CloseHandle(snapshot);

    if (!pid) {
        fprintf(stderr, "Process '%s' not found\n", proc_name);
        return 1;
    }

    printf("Found %s (PID: %lu)\n", proc_name, pid);

    HANDLE process = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
    if (!process) {
        fprintf(stderr, "OpenProcess failed: %lu\n", GetLastError());
        return 1;
    }

    size_t path_len = strlen(dll_path) + 1;
    LPVOID remote_mem = VirtualAllocEx(process, NULL, path_len, MEM_COMMIT, PAGE_READWRITE);
    if (!remote_mem) {
        fprintf(stderr, "VirtualAllocEx failed: %lu\n", GetLastError());
        CloseHandle(process);
        return 1;
    }

    if (!WriteProcessMemory(process, remote_mem, dll_path, path_len, NULL)) {
        fprintf(stderr, "WriteProcessMemory failed: %lu\n", GetLastError());
        VirtualFreeEx(process, remote_mem, 0, MEM_RELEASE);
        CloseHandle(process);
        return 1;
    }

    HMODULE kernel32 = GetModuleHandleA("kernel32.dll");
    FARPROC loadlib = GetProcAddress(kernel32, "LoadLibraryA");
    if (!loadlib) {
        fprintf(stderr, "GetProcAddress(LoadLibraryA) failed\n");
        VirtualFreeEx(process, remote_mem, 0, MEM_RELEASE);
        CloseHandle(process);
        return 1;
    }

    HANDLE thread = CreateRemoteThread(process, NULL, 0, (LPTHREAD_START_ROUTINE)loadlib, remote_mem, 0, NULL);
    if (!thread) {
        fprintf(stderr, "CreateRemoteThread failed: %lu\n", GetLastError());
        VirtualFreeEx(process, remote_mem, 0, MEM_RELEASE);
        CloseHandle(process);
        return 1;
    }

    printf("Injected! Waiting for thread...\n");
    WaitForSingleObject(thread, INFINITE);

    DWORD exit_code = 0;
    GetExitCodeThread(thread, &exit_code);
    printf("LoadLibrary returned: %lu\n", exit_code);

    VirtualFreeEx(process, remote_mem, 0, MEM_RELEASE);
    CloseHandle(thread);
    CloseHandle(process);

    return exit_code ? 0 : 1;
}
