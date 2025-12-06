; Advent of Code 2025 - Day 1

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
    inputPath db "input/day1.txt", 0
    newline   db 10

    label1 db "Password 1: ", 0
    label2 db "Password 2: ", 0

    angle1    dd 50
    angle2    dd 50

    password1 dd 0
    password2 dd 0

section .bss
    buffer       resb 4096
    lineBuffer   resb 256
    numberBuffer resb 16
    lineLen      resd 1

section .text

_start:
    ; open file
    mov     rax, SYS_OPEN
    mov     rdi, inputPath
    mov     rsi, O_RDONLY
    xor     rdx, rdx
    syscall

    mov     r12, rax           ; fd in R12
    mov     dword [lineLen], 0 ; no chars in current line yet

ReadLoop:
    ; read up to 4096 bytes
    mov     rax, SYS_READ
    mov     rdi, r12
    mov     rsi, buffer
    mov     rdx, 4096
    syscall

    cmp     rax, 0
    jle     EOF         ; <=0 -> EOF or error

    mov     rdi, buffer ; scan pointer
    mov     rbp, rax    ; bytes remaining in this chunk

ScanChunk:
    cmp     rbp, 0
    je      ReadLoop ; chunk done, read next

    mov     al, [rdi]

    ; windows can be a fucking bitch
    ; handle (CR) -> just skip
    cmp     al, 13
    je      SkipCR

    ; handle LF (10) -> end of line
    cmp     al, 10
    je      EndOfLine

    ; normal character -> append to lineBuffer if space left
    mov     edx, [lineLen]
    cmp     edx, 255  ; leave 1 byte for NULL
    jae     SkipStore ; ignore extra characters if too long
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

EndOfLine:
    ; terminate current line
    mov     edx, [lineLen]
    mov     byte [lineBuffer+rdx], 0

    ; if line isn't empty, process it
    cmp     edx, 0
    je      LineDone

    push    rdi
    mov     rsi, lineBuffer
    call    HandleLine
    pop     rdi

LineDone:
    mov     dword [lineLen], 0 ; reset line length
    inc     rdi
    dec     rbp
    jmp     ScanChunk

; process last line if not newline-terminated, then print result
EOF:
    ; if there is a partial line at EOF, process it
    mov     edx, [lineLen]
    cmp     edx, 0
    jle     PrintResults
    mov     byte [lineBuffer+rdx], 0

    mov     rsi, lineBuffer
    call    HandleLine

PrintResults:
    mov     rcx, label1
    call    PrintString
    mov     eax, [password1]
    call    PrintInt

    ; newline
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    mov     rsi, newline
    mov     rdx, 1
    syscall

    mov     rcx, label2
    call    PrintString
    mov     eax, [password2]
    call    PrintInt

    ; new linhe
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    mov     rsi, newline
    mov     rdx, 1
    syscall

    mov     rax, SYS_CLOSE
    mov     rdi, r12
    syscall
    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall

; Handle one line: RSI -> "L123" or "R45"
HandleLine:
    mov     al, [rsi]
    cmp     al, 'L'
    je      .left
    mov     ebx, 1   ; direction = +1 for 'R' or anything else
    jmp     .after
.left:
    mov     ebx, -1  ; direction = -1 for 'L'
.after:
    inc     rsi      ; skip 'L' or 'R'
    call    ParseInt ; EAX = steps
    mov     ecx, eax

; Part 1
P1_Start:
    mov     eax, ecx
    imul    eax, ebx
    add     eax, [angle1]
    call    NormalizeAngle
    mov     [angle1], eax
    cmp     eax, 0
    jne     P2_Start
    mov     rdi, password1
    mov     edx, [rdi]
    inc     edx
    mov     [rdi], edx

; Part 2
P2_Start:
    mov     rdi, password2
.loop:
    test    ecx, ecx
    jle     P2_Exit
    dec     ecx

    mov     eax, [angle2]
    call    UpdateAngleCount
    mov     [angle2], eax

    jmp     .loop
P2_Exit:
    ret

; normalize eax to 0..99
NormalizeAngle:
    cmp     eax, 0
    jl      .add
    cmp     eax, 100
    jl      .done
    sub     eax, 100
    jmp     NormalizeAngle
.add:
    add     eax, 100
    jmp     NormalizeAngle
.done:
    ret

; eax = angle, ebx = direction, rdi = password counter addr
UpdateAngleCount:
    add     eax, ebx
    call    NormalizeAngle

    cmp     eax, 0
    jne     .done
    mov     edx, [rdi]
    inc     edx
    mov     [rdi], edx
.done:
    ret

; parse ASCII integer into EAX
ParseInt:
    xor     eax, eax     ; result = 0
.parseLoop:
    mov     dl, [rsi]
    cmp     dl, '0'
    jl      .done
    cmp     dl, '9'
    jg      .done

    sub     dl, '0'      ; digit value 0..9
    movzx   edx, dl

    imul    eax, eax, 10 ; result *= 10
    add     eax, edx     ; result += digit

    inc     rsi
    jmp     .parseLoop
.done:
    ret

PrintInt:
    mov     edi, numberBuffer+15 ; write digits from the end
    mov     byte [rdi], 0        ; terminator
    dec     rdi

    cmp     eax, 0
    jne     .convert
    mov     byte [rdi], '0'
    jmp     .finish
.convert:
    ; we will repeatedly compute:
    ;   q = eax / 10
    ;   r = eax % 10
    ; using only subtraction
.nextDigit:
    mov     edx, eax   ; tmp = current value
    mov     ecx, 0     ; q = 0

    cmp     edx, 10    ; if < 0,  q=0, r=edx
    jb      .lastDigit
.subLoop:
    sub     edx, 10
    inc     ecx        ; q++
    cmp     edx, 10
    jae     .subLoop   ; while tmp >= 10
.lastDigit:
    ; now:
    ;   ecx = quotient
    ;   edx = remainder (0..9)
    add     dl, '0'
    mov     [rdi], dl  ; store digit
    dec     rdi
    mov     eax, ecx   ; eax = quotient
    test    eax, eax
    jnz     .nextDigit ; more digits to extract?

    inc     rdi        ; move to first digit
.finish:
    mov     rax, SYS_WRITE
    mov     rsi, rdi              ; buffer pointer
    mov     rdi, STDOUT
    mov     rdx, numberBuffer+15
    sub     rdx, rsi              ; length
    syscall
    ret

PrintString:
    push    rcx
    push    rdx
    mov     rdx, 0
.count:
    cmp     byte [rcx+rdx], 0
    je      .doneCount
    inc     rdx
    jmp     .count
.doneCount:
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    mov     rsi, rcx
    syscall

    pop     rdx
    pop     rcx
    ret
