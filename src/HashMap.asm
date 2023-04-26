;x86_64, NASM-style assembly
;uses the C Standard Library
;MS calling convention

extern malloc
extern calloc
extern realloc
extern free

extern memset
extern memcpy
extern memmove

global HM_defaultHash
global HM_defaultEquals

global HashMapDefault
global HashMapCapacity
global HM_put
global HM_remove

defaultSize:    equ 16
defaultResize:  equ 12

struc Node
.key:           resq 1
.value:         resq 1
.nextNode:      resq 1
endstruc

struc Map
.nodesPtr:      resq 1
.bucketsPtr:    resq 1
.hash:          resq 1
.equals:        resq 1
.size:          resd 1
.nextResize:    resd 1
.allocatedMem:  resd 1  ;in elements
endstruc

section .text
HM_defaultHash:    ;the elements are their own hases
    mov rax, rcx
    ret

HM_defaultEquals:    ;arguments are compared with simple numerical equality
    cmp rcx, rdx
    sete al
    ret

HashMapDefault:
    mov r8d, defaultSize
    mov r9d, defaultResize
    jmp HM_CapLFskip

HashMapCapacity:
    mov r9d, r8d
    cmp r8d, defaultSize
    jbe HashMapDefault  ;argument is smaller than defaultSize

    dec r8d
    and r8d, r9d
    jz HMC_collect  ;exactly one bit is set

    bsr ecx, r9d
    mov r9d, 1
    inc cl
    shl r9d, cl ;the smallest power of two greater than argument
    mov r8d, r9d
    ;jmp HMC_collect
HMC_collect:
    lea r9, [r9 + r9 * 2]   ;{mul by 3/4 (default loadFactor)
    shr r9d, 2              ;}
    jmp HM_CapLFskip

HashMapCapLF:
    cvtsi2ss xmm1, r8d
    mulss xmm1, xmm3
    cvtss2si r9d, xmm1
HM_CapLFskip:   ;skip calculating nextResize
    push rbx
    push rbp
    push rdi
    sub rsp, 0x20

    mov rbx, rcx
    mov rbp, rdx
    mov edi, r9d
    shl r8, 0x20
    or rdi, r8

    mov ecx, Map_size
    call malloc
    mov [rax + Map.hash], rbx
    mov [rax + Map.equals], rbp
    mov [rax + Map.nextResize], edi
    mov dword [rax + Map.size], 0
    shr rdi, 0x20
%if Node_size != 24
    %error "Node size changed"
%endif
    mov [rax + Map.allocatedMem], edi
    shl edi, 3              ;{size * 8 in edi
    lea rcx, [rdi + rdi * 2];}size * 24 in ecx
    mov rbx, rax
    call malloc
    mov [rbx + Map.nodesPtr], rax

    mov ecx, edi
    mov edx, 1
    call calloc
    mov [rbx + Map.bucketsPtr], rax

    mov rax, rbx
    add rsp, 0x20
    pop rdi
    pop rbp
    pop rbx
    ret

HM_clear:
    sub rsp, 0x20
    xor edx, edx
    mov [rcx + Map.size], edx
    mov r8d, [rcx + Map.allocatedMem]
    mov rcx, [rcx + Map.bucketsPtr]
    shl r8d, 3
    call memset
    add rsp, 0x20
    ret

HM_containsKey:
    call getNode
    setz al
    ret

HM_containsValue:
    mov r8d, [rcx + Map.size]
    mov rcx, [rcx + Map.nodesPtr]
%if Node_size != 24
    %error "Node size changed"
%endif
    lea r8, [r8 + r8 * 2]
    shl r8d, 3
    jmp CV_loopControl
CV_loop:
        cmp rdx, [rcx + r8 + Node.value]
        je CV_true
CV_loopControl:
        sub r8d, Node_size
        jnc CV_loop
    xor al, al
    jmp CV_ret
CV_true:
    mov al, 1
CV_ret:
    ret

HM_forEach:
    push rbx
    push rbp
    push rdi
    mov rbx, [rcx + Map.nodesPtr]
    mov ebp, [rcx + Map.size]
%if Node_size != 24
    %error "Node size changed"
%endif
    lea rbp, [rbp + rbp * 2]
    shl ebp, 3
    mov rdi, rdx
    jmp FE_loopControl
FE_loop:
        mov rcx, [rbx + rbp + Node.value]
        call rdi
FE_loopControl:
        sub ebp, Node_size
        jnc FE_loop
    pop rdi
    pop rbp
    pop rbx
    ret

getMappedBucket:    ;map ptr in rbx, key in rbp
;sets ZF according to result
    mov rax, [rbx + Map.hash]
    mov rcx, rbp
    sub rsp, 0x20
    call rax
    add rsp, 0x20
    mov edx, [rbx + Map.allocatedMem]
    dec edx
    and edx, eax
    mov rcx, [rbx + Map.bucketsPtr]
    lea rcx, [rcx + rdx * 8]
    mov rax, [rcx]
    test rax, rax
    ret

getNode:    ;map ptr in rcx, key in rdx
;sets ZF according to resulting Node address
    push rbx
    push rbp
    push rdi
    sub rsp, 0x20
    mov rbx, rcx
    mov rbp, rdx
    call getMappedBucket
    jz GN_null
    mov rdi, [rbx + Map.equals]
GN_loop:
        mov rbx, rax
        mov rcx, [rbx + Node.key]
        mov rdx, rbp
        call rdi
        test al, al
        mov rax, rbx
        jnz GN_ret  ;this is the sought node
        mov rax, [rbx + Node.nextNode]
        test rax, rax
        jnz GN_loop
        ;else this is the last node in this bucket
GN_null:
    xor eax, eax
GN_ret:
    add rsp, 0x20
    pop rdi
    pop rbp
    pop rbx
    ret

HM_get:
    call getNode
    jz GET_null
    mov rax, [rax + Node.value]
    ret
GET_null:
    xor eax, eax
    ret

HM_getOrDefault:
    push r8
    call getNode
    jz GOD_default
    mov rax, [rax + Node.value]
    add rsp, 8
    ret
GOD_default:
    pop rax
    ret

HM_isEmpty:
    mov eax, [rcx + Map.size]
    test eax, eax
    setz al
    ret

HM_putIfAbsent:
    push rbx
    push rdi
    mov rbx, rcx
    mov rdi, rdx
    call HM_containsKey
    test al, al
    mov rcx, rbx
    mov rdx, rdi
    jz PUT_skipPush
    pop rdi
    pop rbx
    ret

HM_put:
    push rbx
    push rdi
PUT_skipPush:
    push rbp
    push rsi
    sub rsp, 0x20
    mov rbx, rcx    ;Map ptr
    mov rbp, r8     ;element
    mov rdi, rdx    ;key
    mov eax, [rcx + Map.size]
    mov ecx, [rbx + Map.nextResize]
    cmp eax, ecx
    je PUT_resizeAndRehash
PUT_enoughCapacity:
    mov rax, [rbx + Map.hash]
    mov rcx, rdi    ;key
    call rax    ;hashing function
    mov edx, [rbx + Map.allocatedMem]
    dec edx
    and edx, eax    ;hash modulo capacity

    mov rcx, [rbx + Map.bucketsPtr]
    mov r8, [rcx + rdx * 8] ;currently mapped node (if any)
    test r8, r8
    jnz PUT_collision

    lea r8, [rcx + rdx * 8] ;occupy new bucket
    jmp PUT_newNode

PUT_resizeAndRehash:
    sub rsp, 0x20
    mov rcx, [rbx + Map.nodesPtr]
    shl dword [rbx + Map.nextResize], 1
    mov esi, [rbx + Map.allocatedMem]
    shl esi, 1
    mov [rbx + Map.allocatedMem], esi   ;doubling memory allocation
%if Node_size != 24
    %error "Node size changed"
%endif
    lea rdx, [rsi * 8]
    lea rdx, [rdx + rdx * 2];allocatedMem * 24 * 2
    call realloc
    mov [rbx + Map.nodesPtr], rax
    mov rcx, [rbx + Map.bucketsPtr]
    lea rdx, [rsi * 8];allocatedMem * 8 * 2
    call realloc
    mov [rbx + Map.bucketsPtr], rax
    ;rehashing
    add rsp, 0x20
    push rbp
    push rdi
    push r15
    push r14
    push r13
    sub rsp, 0x20
    mov r15, [rbx + Map.hash]
    mov r14, [rbx + Map.bucketsPtr]
    mov rbp, [rbx + Map.nodesPtr]
    lea rdi, [rsi - 1]  ;for modulo'ing hashes
    mov r13d, [rbx + Map.size]
%if Node_size != 24
    %error "Node size changed"
%endif
    lea r13, [r13 + r13 * 2]
    shl r13, 3
    mov r8d, [rbx + Map.allocatedMem]
    shl r8d, 3
    xor edx, edx
    mov rcx, r14
    call memset
    jmp PUT_RnR_loopControl
PUT_RnR_loop0:
        xor edx, edx
        mov [rbp + r13 + Node.nextNode], rdx
        mov rcx, [rbp + r13 + Node.key]
        call r15
        and eax, edi    ;hash modulo capacity
        lea rcx, [r14 + rax * 8]
        RnR_loop1:
        mov rdx, [rcx]
        test rdx, rdx
        jz RnR_newBucket
        ;else linkNodes
        mov rcx, [rdx + Node.nextNode]
        jmp RnR_loop1
        RnR_newBucket:
        lea rdx, [rbp + r13]
        mov [rcx], rdx
PUT_RnR_loopControl:
        sub r13d, Node_size
        jnc PUT_RnR_loop0
    add rsp, 0x20
    pop r13
    pop r14
    pop r15
    pop rdi
    pop rbp
    ;rsi doesn't need to be popped from the stack
    jmp PUT_enoughCapacity

PUT_collision:
    mov rsi, r8
PUT_collisionLoop:
    mov rax, [rbx + Map.equals]
    mov rdx, [rsi + Node.key]
    mov rcx, rdi
    call rax
    test al, al
    jnz PUT_remap
    mov r10, rsi  ;save Node ptr in case of PUT_newNode
    mov rsi, [rsi + Node.nextNode]
    test rsi, rsi
    jnz PUT_collisionLoop

    lea r8, [r10 + Node.nextNode]
    ;jmp PUT_newNode

PUT_newNode:    ;map ptr in rbx, key in rdi, value in rbp, destination ptr for the new node in r8
    mov r9d, [rbx + Map.size]
%if Node_size != 24
    %error "Node size changed"
%endif
    shl r9d, 3
    lea r9, [r9 + r9 * 2]
    add r9, [rbx + Map.nodesPtr]
    mov [r9 + Node.key], rdi
    xor eax, eax
    mov [r9 + Node.value], rbp
    mov [r9 + Node.nextNode], rax   ;nullptr

    mov [r8], r9    ;put nodePtr in its destination
    inc dword [rbx + Map.size]
    jmp PUT_ret

PUT_remap:  ;assign new value to an existing node
    mov rax, rbp
    xchg rax, [rsi + Node.value]

PUT_ret:
    add rsp, 0x20
    pop rsi
    pop rbp
    pop rdi
    pop rbx
    ret

HM_remove:
    mov rbx, rcx
    mov rax, [rcx + Map.nodesPtr]
    mov rdi, rax
    lea rsi, [rax + 24]
    call moveNode

    push rbx
    push rbp
    mov rbx, rcx
    mov rbp, rdx
    call getNode
    jz REM_retShallow
    push rdi
    push rsi
    mov rdi, rax
    call getMappedBucket
    cmp rax, rdi
    jne REM_loop0Control
    mov rdx, [rdi + Node.nextNode]
    mov [rcx], rdx
    jmp REM_loop0Collect
REM_loop0:
        cmp rax, rdi
        je REM_bypassRemovedNode
        lea rcx, [rax + Node.nextNode]
REM_loop0Control:
        mov rax, [rcx]
        jmp REM_loop0
REM_bypassRemovedNode:
    mov rdx, [rdi + Node.nextNode]
    mov [rcx], rdx
REM_loop0Collect:
    mov ecx, [rbx + Map.size]
    dec ecx
    mov [rbx + Map.size], ecx
    mov rax, [rbx + Map.nodesPtr]
%if Node_size != 24
    %error "Node size changed"
%endif
    lea rcx, [rcx + rcx * 2] ;rcx * 3
    lea rsi, [rax + rcx * 8] ;the last node
    mov rdx, [rsi + Node.key]
    mov ecx, 3
    rep movsq   ;move the last node to where the removed node is
    mov rcx, rbx
    call getMappedBucket
    jz REM_retDeep
    sub rsi, Node_size
    cmp rax, rsi
    jne REM_loop1Control
REM_loop1:
        cmp rax, rsi
        ;je eq
        lea rcx, [rax + Node.nextNode]
REM_loop1Control:
        mov rax, [rcx]
        jmp REM_loop1
REM_loop1Collect:

    ;mov rdx, [rsi + Node.


REM_retDeep:
    pop rsi
    pop rdi
REM_retShallow:
    pop rbp
    pop rbx
    ret

moveNode:   ;map ptr in rbx, nodes in rsi (source) and rdi (destination)
    push rbp
    push r15
    xor r15d, r15d
MN_repeat:
    mov rbp, [rdi + Node.key]
    call getMappedBucket
    cmp rax, rdi
    jne MN_loop
    test r15b, r15b
    jz MN_bucketDst
    ;MN_bucketSrc:
    mov [rcx], rsi
    jmp MN_collect
    MN_bucketDst:
    xor edx, edx
    mov [rcx], rdx
    jmp MN_collect
MN_loop:
        lea rcx, [rax + Node.nextNode]
        cmp rcx, rdi
        je MN_bypass
        mov rax, [rcx]
        jmp MN_loop
MN_bypass:
    test r15b, r15b
    jz MN_bypassDst
    ;bypassSrc
    mov [rcx], rdi
    jmp MN_collect
MN_bypassDst:
    mov rdx, [rdi + Node.nextNode]
    mov [rcx], rdx

MN_collect:
    inc r15d
    xchg rdi, rsi
    cmp r15b, 1
    je MN_repeat

    mov ecx, 3
    rep movsq
    pop r15
    pop rbp
    ret

HM_size:
    mov eax, [rcx + Map.size]
    ret

HM_free:
    push rbx
    sub rsp, 0x20
    mov rbx, rcx
    mov rcx, [rbx + Map.nodesPtr]
    call free
    mov rcx, [rbx + Map.bucketsPtr]
    call free
    mov rcx, rbx
    call free
    add rsp, 0x20
    pop rbx
    ret
