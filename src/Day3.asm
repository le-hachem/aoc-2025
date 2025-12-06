; Advent of Code 2025 - Day 3

bits 64
default rel

global _start

%define SYS_EXIT   60
%define SYS_READ   0
%define SYS_WRITE  1
%define SYS_OPEN   2
%define SYS_CLOSE  3

%define O_RDONLY   0
%define STDOUT     1

section .data
    inputPath db "input/day3.txt", 0

    newline   db 10

    label1 db "Part 1: ", 0
    label2 db "Part 2: ", 0

section .bss
    buffer       resb 4096
    lineBuffer   resb 65536
    lineLen      resd 1

    sum1         resq 1
    sum2         resq 1

    workDigits   resb 64        ; stack for greedy subsequence
    numberBuffer resb 32        ; for printing

section .text

_start:
    mov     rax, SYS_OPEN
    mov     rdi, inputPath
    mov     rsi, O_RDONLY
    xor     rdx, rdx
    syscall

    mov     r12, rax                 ; fd
    mov     dword [lineLen], 0

ReadLoop:
    mov     rax, SYS_READ
    mov     rdi, r12
    mov     rsi, buffer
    mov     rdx, 4096
    syscall

    cmp     rax, 0
    jle     EOF

    mov     rdi, buffer
    mov     rbp, rax

ScanChunk:
    cmp     rbp, 0
    je      ReadLoop

    mov     al, [rdi]

    cmp     al, 13
    je      SkipCR

    cmp     al, 10
    je      EndLine

    mov     edx, [lineLen]
    cmp     edx, 65535
    jae     SkipStore
    mov     [lineBuffer+rdx], al
    inc     edx
    mov     [lineLen], edx

SkipStore:
    inc     rdi
    dec     rbp
    jmp     ScanChunk

SkipCR:
    inc     rdi
    dec     rbp
    jmp     ScanChunk

EndLine:
    mov     edx, [lineLen]
    mov     byte [lineBuffer+edx], 0

    cmp     edx, 0
    je      ClearLine

    push    rdi
    mov     rsi, lineBuffer
    call    HandleLine
    pop     rdi

ClearLine:
    mov     dword [lineLen], 0
    inc     rdi
    dec     rbp
    jmp     ScanChunk

EOF:
    ; possible last partial line
    mov     edx, [lineLen]
    cmp     edx, 0
    jle     PrintResults

    mov     byte [lineBuffer+edx], 0
    mov     rsi, lineBuffer
    call    HandleLine

PrintResults:
    mov     rcx, label1
    call    PrintString
    mov     rax, [sum1]
    call    PrintInt64
    call    Newline

    mov     rcx, label2
    call    PrintString
    mov     rax, [sum2]
    call    PrintInt64
    call    Newline

    mov     rax, SYS_CLOSE
    mov     rdi, r12
    syscall

    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall

HandleLine:
    mov     rdi, rsi
    xor     ecx, ecx              ; ECX = 0
.lengthLoop:
    mov     al, [rdi+rcx]
    cmp     al, 0
    je      .lengthDone
    inc     ecx
    jmp     .lengthLoop
.lengthDone:
    mov     r15d, ecx             ; r15d = n

    ; part 1: k = 2
    mov     ecx, r15d             ; ECX = n
    mov     edi, 2                ; K = 2
    call    GetMaxForK            ; RAX = best 2-digit value
    add     qword [sum1], rax

    ; part 2: k = 12, only if n >= 12
    cmp     r15d, 12
    jl      .skipPart2

    mov     ecx, r15d
    mov     edi, 12
    call    GetMaxForK            ; RAX = best 12-digit value
    add     qword [sum2], rax

.skipPart2:
    ret

; Greedy lexicographically largest subsequence of length K
;
; Input:
;   RSI -> digits string
;   ECX = n (length)
;   EDI = k
; Output:
;   RAX = numeric value of chosen k digits
; Clobbers: R8..R11, EAX, EDX
GetMaxForK:
    ; dropsRemaining = n - k
    mov     eax, ecx
    sub     eax, edi
    mov     r8d, eax              ; r8d = drops

    xor     r9d, r9d              ; r9d = stackSize
    xor     r10d, r10d            ; r10d = i

.loop:
    cmp     r10d, ecx
    jge     .after_input

    ; current digit in AL
    mov     r11, r10
    mov     al, [rsi + r11]

.pop:
    cmp     r9d, 0
    jle     .push
    cmp     r8d, 0
    jle     .push

    mov     edx, r9d
    dec     edx
    mov     r11d, edx
    mov     bl, [workDigits + r11]

    cmp     bl, al
    jge     .push

    dec     r9d
    dec     r8d
    jmp     .pop
.push:
    mov     r11d, r9d
    mov     [workDigits + r11], al
    inc     r9d
    inc     r10d
    jmp     .loop

.after_input:
    ; trim if stackSize > k
.trim:
    cmp     r9d, edi
    jle     .convert
    dec     r9d
    jmp     .trim
.convert:
    xor     rax, rax
    xor     r11d, r11d
.convertLoop:
    cmp     r11d, edi
    jge     .done

    mov     rdx, r11
    mov     dl, [workDigits + rdx]
    sub     dl, '0'
    movzx   rdx, dl

    imul    rax, rax, 10
    add     rax, rdx

    inc     r11d
    jmp     .convertLoop
.done:
    ret

Newline:
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    mov     rsi, newline
    mov     rdx, 1
    syscall
    ret

PrintInt64:
    mov     rdi, numberBuffer+31
    mov     byte [rdi], 0
    dec     rdi

    cmp     rax, 0
    jne     .conv

    mov     byte [rdi], '0'
    jmp     .done
.conv:
    mov     rbx, 10
.next:
    xor     rdx, rdx
    div     rbx
    add     dl, '0'
    mov     [rdi], dl
    dec     rdi
    test    rax, rax
    jnz     .next

    inc     rdi
.done:
    mov     rax, SYS_WRITE
    mov     rsi, rdi
    mov     rdi, STDOUT
    mov     rdx, numberBuffer+31
    sub     rdx, rsi
    syscall
    ret

PrintString:
    push    rcx
    push    rdx
    mov     rdx, 0
.length:
    cmp     byte [rcx+rdx], 0
    je      .submit
    inc     rdx
    jmp     .length
.submit:
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    mov     rsi, rcx
    syscall
    pop     rdx
    pop     rcx
    ret
