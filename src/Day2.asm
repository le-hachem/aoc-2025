; Advent of Code 2025 – Day 2

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
    inputPath db "input/day2.txt", 0
    newline   db 10

    label1 db "Part 1: ", 0
    label2 db "Part 2: ", 0

section .bss
    buffer       resb 4096
    lineBuffer   resb 65536
    lineLen      resd 1

    sum1         resq 1
    sum2         resq 1

    numberBuffer resb 32     ; for printing and NumberToString

section .text

_start:
    mov     rax, SYS_OPEN
    mov     rdi, inputPath
    mov     rsi, O_RDONLY
    xor     rdx, rdx
    syscall

    mov     r12, rax                 ; file descriptor
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
    mov     byte [lineBuffer+rdx], 0

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
    ; process final partial line if needed
    mov     edx, [lineLen]
    cmp     edx, 0
    jle     PrintResults

    mov     byte [lineBuffer+rdx], 0
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

; parse "A-B,C-D,..."l, RSI = pointer to line
; uses r13 = current ID, r14 = end of range
HandleLine:
NextRange:
    ; parse start
    call    ParseInt64
    mov     r13, rax

    cmp     byte [rsi], '-'
    jne     DoneLine
    inc     rsi

    ; parse end
    call    ParseInt64
    mov     r14, rax

RangeLoop:
    cmp     r13, r14
    jg      AfterRange

    ; Save RSI (line pointer) across the checks,
    ; because NumberToString / CheckInvalid* use RSI
    push    rsi

    ; Part 1: exact AA
    mov     rax, r13
    call    CheckInvalid1
    test    rax, rax
    jz      .skipP1
    add     qword [sum1], r13
.skipP1:
    ; Part 2: any repeating block >= 2
    mov     rax, r13
    call    CheckInvalid2
    test    rax, rax
    jz      .skipP2
    add     qword [sum2], r13
.skipP2:
    pop     rsi ; restore line pointer

    inc     r13
    jmp     RangeLoop

AfterRange:
    cmp     byte [rsi], ','
    jne     DoneLine
    inc     rsi
    jmp     NextRange

DoneLine:
    ret

; RSI points at decimal digits; stops on first non-digit
ParseInt64:
    xor     rax, rax
.parse:
    mov     dl, [rsi]
    cmp     dl, '0'
    jl      .done
    cmp     dl, '9'
    jg      .done

    sub     dl, '0'
    movzx   rdx, dl
    imul    rax, rax, 10
    add     rax, rdx

    inc     rsi
    jmp     .parse
.done:
    ret

; NumberToString: convert RAX to decimal ASCII, MSB-first
;   Output:
;     RSI = pointer to first digit
;     ECX = length
NumberToString:
    mov     rdi, numberBuffer+31
    mov     byte [rdi], 0        ; terminator (for convenience)
    dec     rdi

    cmp     rax, 0
    jne     .conv

    ; handle zero
    mov     byte [rdi], '0'
    mov     rsi, rdi
    mov     ecx, 1
    ret

.conv:
    mov     rbx, 10
.nextDigit:
    xor     rdx, rdx
    div     rbx                  ; RAX = quotient, RDX = remainder
    add     dl, '0'
    mov     [rdi], dl
    dec     rdi
    test    rax, rax
    jnz     .nextDigit

    inc     rdi                  ; now RDI points to first digit
    mov     rsi, rdi
    mov     rdx, numberBuffer+31
    sub     rdx, rsi             ; RDX = length
    mov     ecx, edx
    ret

; CheckInvalid1: "AA" pattern
;   RAX = number
;   Returns RAX = 1 if digits == A A, else 0
CheckInvalid1:
    push    rbx
    push    rdx

    call    NumberToString       ; RSI=string, ECX=len
    mov     eax, ecx             ; EAX = len

    cmp     eax, 2
    jl      .no1

    test    eax, 1
    jnz     .no1                 ; odd length => cannot be AA

    shr     eax, 1               ; half = len/2
    mov     r8d, eax             ; half
    xor     r9d, r9d             ; i = 0

.loop1:
    cmp     r9d, r8d
    jge     .yes1

    ; s[i]
    mov     rdx, r9
    movzx   eax, byte [rsi + rdx]

    ; s[i+half]
    mov     rdx, r9
    add     rdx, r8
    movzx   ebx, byte [rsi + rdx]

    cmp     eax, ebx
    jne     .no1

    inc     r9d
    jmp     .loop1

.yes1:
    mov     rax, 1
    jmp     .ret1

.no1:
    xor     rax, rax

.ret1:
    pop     rdx
    pop     rbx
    ret

; CheckInvalid2: any repeating block >= 2
;   RAX = number
;   Returns RAX = 1 if string is some A repeated k>=2 times
CheckInvalid2:
    push    rbx
    push    rdx

    call    NumberToString       ; RSI=string, ECX=len
    mov     r11d, ecx            ; n = length

    cmp     r11d, 2
    jb      .no2

    mov     r8d, 1               ; m = 1 (candidate period)
.outer:
    cmp     r8d, r11d
    jge     .no2

    ; if n % m != 0 => cannot tile
    mov     eax, r11d
    xor     edx, edx
    div     r8d                  ; EAX=q, EDX=r
    test    edx, edx
    jnz     .next_m

    mov     r9d, r11d
    sub     r9d, r8d             ; limit = n - m
    xor     r10d, r10d           ; i = 0
.inner:
    cmp     r10d, r9d
    jge     .yes2                ; all positions checked

    ; s[i]
    mov     rdx, r10
    movzx   eax, byte [rsi + rdx]

    ; s[i+m]
    mov     rdx, r10
    add     rdx, r8
    movzx   ebx, byte [rsi + rdx]

    cmp     eax, ebx
    jne     .next_m

    inc     r10d
    jmp     .inner
.yes2:
    mov     rax, 1
    jmp     .ret2
.next_m:
    inc     r8d
    jmp     .outer
.no2:
    xor     rax, rax
.ret2:
    pop     rdx
    pop     rbx
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
