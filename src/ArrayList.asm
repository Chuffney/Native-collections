;x86_64, NASM-style assembly
;uses the C Standard Library
;MS calling convention

extern malloc
extern realloc
extern free

extern memcpy
extern memmove


global ArrayListDefault
global ArrayListCopy
global ArrayListCapacity

global AL_trimToSize
global AL_ensureCapacity
global AL_isEmpty
global AL_contains
global AL_indexOf
global AL_lastIndexOf
global AL_clone
global AL_toArray
global AL_get
global AL_set
global AL_add
global AL_addInside
global AL_remove
global AL_removeElement
global AL_clear
global AL_free

defaultSize:    equ 16 * 8

struc List
.arrayPtr:      resq 1
.size:          resd 1 ;index of first free space in array
.allocatedMem:  resd 1 ;in bytes
endstruc

section .text
ArrayListDefault:
    sub rsp, 0x20
    mov ecx, List_size
    call malloc
    mov [rsp + 0x18], rax
    mov ecx, defaultSize
    call malloc
    mov rcx, [rsp + 0x18]
    mov [rcx + List.arrayPtr], rax
    mov dword [rcx + List.size], 0
    mov dword [rcx + List.allocatedMem], defaultSize
    mov rax, rcx
    add rsp, 0x20
    ret

ArrayListCopy:
    push rbx
    sub rsp, 0x20
    mov rbx, rcx
    mov ecx, [rcx + List.size]
    call ArrayListCapacity
    mov rdx, [rbx + List.arrayPtr]
    mov rcx, [rax + List.arrayPtr]
    mov r8d, [rbx + List.size]
    mov [rax + List.size], r8d
    shl r8d, 3
    mov rbx, rax
    call memcpy
    mov rax, rbx
    add rsp, 0x20
    pop rbx
    ret

ArrayListCapacity:
    push rbx
    sub rsp, 0x20
    mov ecx, ecx
    lea rbx, [rcx * 8]  ;memory required
    mov ecx, List_size
    call malloc
    mov [rax + List.allocatedMem], ebx
    mov dword [rax + List.size], 0
    mov ecx, ebx    ;moving capacity to argument
    mov rbx, rax    ;storing struct address
    call malloc
    mov [rbx + List.arrayPtr], rax
    mov rax, rbx
    add rsp, 0x20
    pop rbx
    ret

AL_trimToSize:
    push rcx
    sub rsp, 0x20
    mov edx, [rcx + List.size]
    test edx, edx
    setz dl    ;if size = 0, change it to 1 to avoid realloc deallocating memory

    shl edx, 3  ;multiply by 8
    mov [rcx + List.allocatedMem], edx
    mov rcx, [rcx + List.arrayPtr]
    call realloc
    add rsp, 0x20
    pop rcx
    mov [rcx + List.arrayPtr], rax
    ret

AL_ensureCapacity:
    shl edx, 3
    mov eax, [rcx + List.allocatedMem]
    cmp eax, edx
    jae EC_ret  ;jmp if enough memory is already allocated
    ;else
    push rcx
    sub rsp, 0x20
    mov rcx, [rcx + List.arrayPtr]
    call realloc
    add rsp, 0x20
    pop rcx
    mov [rcx + List.arrayPtr], rax
    EC_ret:
    ret


AL_isEmpty:
    mov ecx, [rcx + List.size]
    test ecx, ecx
    setz al
    ret

AL_contains:
    call indexOf
    cmp eax, 0xFFFFFFFF ;unsigned "-1"
    setne al    ;if indexOf(element) != -1 return 1;
    ret

indexOf:
AL_indexOf:
    mov r9d, [rcx + List.size]  ;limit
    mov r8, [rcx + List.arrayPtr]   ;array
    xor eax, eax    ;iterator
    jmp IO_loopControl
    IO_loop:
        mov rcx, [r8 + rax * 8]
        cmp rcx, rdx
        je IO_ret
        inc eax
    IO_loopControl:
        cmp eax, r9d
        jb IO_loop
    mov eax, 0xFFFFFFFF
IO_ret:
    ret

AL_lastIndexOf:
    mov r8, [rcx + List.arrayPtr]
    mov eax, [rcx + List.size]
    jmp LIO_loopControl
LIO_loop:
        dec eax
        mov rcx, [r8 + rax * 8]
        cmp rcx, rdx
        je LIO_ret
LIO_loopControl:
        test eax, eax
        jnz LIO_loop
    mov eax, 0xFFFFFFFF
LIO_ret:
    ret


AL_clone:
    jmp ArrayListCopy

AL_toArray:
    push rcx
    sub rsp, 0x20
    mov ecx, [rcx + List.size]
    shl ecx, 3
    call malloc
    mov rdx, [rsp + 0x20]
    mov r8d, [rdx + List.size]
    shl r8d, 3
    mov rdx, [rdx + List.arrayPtr]
    mov rcx, rax
    call memcpy
    add rsp, 0x28
    ret

AL_get:
    mov edx, edx
    mov rcx, [rcx + List.arrayPtr]
    mov rax, [rcx + rdx * 8]
    ret

AL_set:
    mov edx, edx
    mov rax, r8
    mov rcx, [rcx + List.arrayPtr]
    xchg rax, [rcx + rdx * 8]
SET_ret:
    ret

;makes sure that at least one more element will fit in the allocated memory
staticEnsureCapacity:   ;preserves rcx, rdx and r8. Returns first free address offset (from array base)
    mov eax, [rcx + List.size]
    mov r9d, [rcx + List.allocatedMem]
    lea rax, [8 + rax * 8]  ;total memory needed to hold one more element
    cmp r9d, eax
    jae SEC_ret
    ;else realloc
    push rcx
    push rdx
    push r8
    sub rsp, 0x20
    lea rdx, [r9 * 2]
    mov [rcx + List.allocatedMem], rdx
    mov rcx, [rcx + List.arrayPtr]
    call realloc
    add rsp, 0x20
    pop r8
    pop rdx
    pop rcx
    mov [rcx + List.arrayPtr], rax
    mov eax, [rcx + List.size]
    lea rax, [8 + rax * 8]
SEC_ret:
    sub eax, 8
    ret

AL_add:
    call staticEnsureCapacity
    add rax, [rcx + List.arrayPtr]
    mov [rax], rdx
    inc dword [rcx + List.size]
    mov al, 1
    ret

AL_addInside:
    mov edx, edx
    call staticEnsureCapacity
    push r8
    sub rsp, 0x20
    mov r8d, [rcx + List.size]
    shl r8d, 3
    shl edx, 3
    sub r8d, edx    ;how many bytes need to be moved
    add rdx, [rcx + List.arrayPtr]
    lea rcx, [rdx + 8]
    call memmove    ;overlapping memory (memcpy -> memmove)
    add rsp, 0x20
    pop r8
    mov [rax - 8], r8
    ret


remove:
AL_remove:
    mov edx, edx
    mov r8d, [rcx + List.size]
    dec r8d
    mov [rcx + List.size], r8d
    mov rcx, [rcx + List.arrayPtr]
    mov rax, [rcx + rdx * 8]
    push rax
    sub rsp, 0x20

    sub r8d, edx    ;how many elements need to be moved
    shl edx, 3  ;destination offset
    shl r8d, 3  ;how many bytes...
    add rdx, rcx    ;add arrayPtr
    lea rcx, [rdx + 8]  ;source
    xchg rcx, rdx
    call memmove
    add rsp, 0x20
    pop rax
    ret

AL_removeElement:
    push rcx
    call indexOf
    inc eax
    jz RE_false
    pop rcx
    lea rdx, [rax - 1]  ;indexOf clears upper half of rax
    call remove
    mov al, 1
    ret
RE_false:
    add rsp, 8  ;no need to restore rcx from stack
    ret

AL_clear:
    mov dword [rcx + List.size], 0
    ret

AL_free:
    push rcx
    sub rsp, 0x20
    mov rcx, [rcx + List.arrayPtr]
    call free
    mov rcx, [rsp + 0x20]
    call free
    add rsp, 0x28
    ret
