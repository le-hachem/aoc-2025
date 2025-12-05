; Advent of Code 2025 - Day 1

;
; #include <stdio.h>
; #include <stdlib.h>
; #include <stddef.h>
; #include <stdint.h>
;
; int main(void)
; {
;     FILE* input = fopen("input/day1.txt", "r");
;
;     int32_t angle1 = 50;
;     int32_t angle2 = 50;
;
;     int32_t password1 = 0;
;     int32_t password2 = 0;
;
;     char line[256];
;     while (fgets(line, sizeof(line), input))
;     {
;         int32_t direction = (line[0] == 'L') ? -1 : 1;
;         int32_t steps     = atoi(line + 1);
;
;         // part 1
;         angle1 += direction * steps;
;         angle1 %= 100;
;         if (angle1 < 0)
;             angle1 += 100;
;         if (angle1 == 0)
;             password1++;
;
;         // part 2
;         for (int i = 0; i < steps; i++)
;         {
;             angle2 = ((angle2 + direction) % 100 + 100) % 100;
;             if (angle2 == 0)
;                 password2++;
;         }
;     }
;
;     fclose(input);
;
;     printf("Password 1: %d\n", password1);
;     printf("Password 2: %d\n", password2);
; }

global _start

%define SYS_EXIT   1
%define SYS_READ   3
%define SYS_WRITE  4
%define SYS_OPEN   5
%define SYS_CLOSE  6

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
    mov eax, SYS_OPEN
    mov ebx, inputPath
    mov ecx, O_RDONLY
    int 0x80

    mov esi, eax           ; fd in ESI
    mov dword [lineLen], 0 ; no chars in current line yet

ReadLoop:
    ; read up to 4096 bytes
    mov eax, SYS_READ
    mov ebx, esi
    mov ecx, buffer
    mov edx, 4096
    int 0x80

    cmp eax, 0
    jle EOF         ; <=0 -> EOF or error

    mov edi, buffer ; scan pointer
    mov ebp, eax    ; bytes remaining in this chunk

ScanChunk:
    cmp ebp, 0
    je ReadLoop ; chunk done, read next

    mov al, [edi]

    ; windows can be a fucking bitch
    ; handle (CR) -> just skip
    cmp al, 13
    je SkipCR

    ; handle LF (10) -> end of line
    cmp al, 10
    je EndOfLine

    ; normal character -> append to lineBuffer if space left
    mov edx, [lineLen]
    cmp edx, 255  ; leave 1 byte for NULL
    jae SkipStore ; ignore extra characters if too long
    mov [lineBuffer+edx], al
    inc edx
    mov [lineLen], edx

SkipStore:
    inc edi
    dec ebp
    jmp ScanChunk

SkipCR:
    inc edi
    dec ebp
    jmp ScanChunk

EndOfLine:
    ; terminate current line
    mov edx, [lineLen]
    mov byte [lineBuffer+edx], 0

    ; if line isn't empty, process it
    cmp edx, 0
    je LineDone

    push esi
    push edi
    mov esi, lineBuffer
    call HandleLine
    pop edi
    pop esi

LineDone:
    mov dword [lineLen], 0 ; reset line length
    inc edi
    dec ebp
    jmp ScanChunk

; process last line if not newline-terminated, then print result
EOF:
    ; if there is a partial line at EOF, process it
    mov edx, [lineLen]
    cmp edx, 0
    jle PrintResults
    mov byte [lineBuffer+edx], 0

    push esi
    mov esi, lineBuffer
    call HandleLine
    pop esi

PrintResults:
    mov ecx, label1
    call PrintString
    mov eax, [password1]
    call PrintInt

    ; newline
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov ecx, newline
    mov edx, 1
    int 0x80

    mov ecx, label2
    call PrintString
    mov eax, [password2]
    call PrintInt

    ; new linhe
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov ecx, newline
    mov edx, 1
    int 0x80

    mov eax, SYS_CLOSE
    mov ebx, esi
    int 0x80
    mov eax, SYS_EXIT
    xor ebx, ebx
    int 0x80

; Handle one line: ESI -> "L123" or "R45"
HandleLine:
    mov al, [esi]
    cmp al, 'L'
    je .left
    mov ebx, 1  ; direction = +1 for 'R' or anything else
    jmp .after
.left:
    mov ebx, -1 ; direction = -1 for 'L'
.after:
    inc esi       ; skip 'L' or 'R'
    call ParseInt ; EAX = steps
    mov ecx, eax

; Part 1
P1_Start:
    mov eax, [angle1]
    imul eax, ebx
    add eax, [angle1]
    call NormalizeAngle
    mov [angle1], eax
    cmp eax, 0
    jne P2_Start
    mov edi, password1
    mov edx, [edi]
    inc edx
    mov [edi], edx

; Part 2
P2_Start:
    mov edi, password2
.loop:
    test ecx, ecx
    jle P2_Exit
    dec ecx

    mov eax, [angle2]
    call UpdateAngleCount
    mov [angle2], eax

    jmp .loop
P2_Exit:
    ret

; normalize eax to 0..99
NormalizeAngle:
    cmp eax, 0
    jl .add
    cmp eax, 100
    jl .done
    sub eax, 100
    jmp NormalizeAngle
.add:
    add eax, 100
    jmp NormalizeAngle
.done:
    ret

; eax = angle, ebx = direction, edi = password counter addr
UpdateAngleCount:
    add eax, ebx
    call NormalizeAngle

    cmp eax, 0
    jne .done
    mov edx, [edi]
    inc edx
    mov [edi], edx
.done:
    ret

; parse ASCII integer into EAX
ParseInt:
    xor eax, eax ; result = 0
.parseLoop:
    mov dl, [esi]
    cmp dl, '0'
    jl .done
    cmp dl, '9'
    jg .done

    sub dl, '0' ; digit value 0..9
    movzx edx, dl

    imul eax, eax, 10 ; result *= 10
    add eax, edx      ; result += digit

    inc esi
    jmp .parseLoop
.done:
    ret

PrintInt:
    mov edi, numberBuffer+15 ; write digits from the end
    mov byte [edi], 0        ; terminator
    dec edi

    cmp eax, 0
    jne .convert
    mov byte [edi], '0'
    jmp .finish
.convert:
    ; we will repeatedly compute:
    ;   q = eax / 10
    ;   r = eax % 10
    ; using only subtraction
.nextDigit:
    mov edx, eax   ; tmp = current value
    mov ecx, 0     ; q = 0

    cmp edx, 10    ; if < 0,  q=0, r=edx
    jb .lastDigit
.subLoop:
    sub edx, 10
    inc ecx        ; q++
    cmp edx, 10
    jae .subLoop   ; while tmp >= 10
.lastDigit:
    ; now:
    ;   ecx = quotient
    ;   edx = remainder (0..9)
    add dl, '0'
    mov [edi], dl  ; store digit
    dec edi
    mov eax, ecx   ; eax = quotient
    test eax, eax
    jnz .nextDigit ; more digits to extract?

    inc edi        ; move to first digit
.finish:
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov ecx, edi
    mov edx, numberBuffer+15
    sub edx, edi   ; length
    int 0x80
    ret

PrintString:
    push ecx
    push edx
    mov edx, 0
.count:
    cmp byte [ecx+edx], 0
    je .doneCount
    inc edx
    jmp .count
.doneCount:
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    int 0x80

    pop edx
    pop ecx
    ret
