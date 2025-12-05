; Advent of Code 2025 - Day 1.1

; #include <stddef.h>
; #include <stdio.h>
; #include <stdlib.h>
; #include <stdint.h>
;
; int main(void)
; {
;     FILE* input = fopen("input/day1.txt", "r");
;
;     int32_t angle = 50;
;     int32_t password = 0;
;
;     char line[256];
;     while (fgets(line, sizeof(line), input))
;     {
;         int32_t direction = (line[0] == 'L') ? -1 : 1;
;         int32_t steps = atoi(line + 1);
;
;         angle += direction * steps;
;         angle = (angle % 100 + 100) % 100;
;
;         if (angle == 0)
;             password++;
;     }
;
;     fclose(input);
;     printf("Password: %d\n", password);
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
    newline   db 10                ; '\n'

    angle    dd 50                 ; initial angle
    password dd 0                  ; result counter

section .bss
    buffer       resb 4096         ; chunk read buffer
    lineBuffer   resb 256          ; one line max 255 chars + NUL
    numberBuffer resb 16           ; for PrintInt
    lineLen      resd 1            ; current line length

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
    jle EOF         ; 0 or negative = EOF or error

    mov edi, buffer ; scan pointer
    mov ecx, eax    ; bytes remaining in this chunk

ScanChunk:
    cmp ecx, 0
    je ReadLoop   ; chunk done, read next

    mov al, [edi]

    ; windows can be a fucking bitch
    ; handle CR (13) -> just skip
    cmp al, 13
    je SkipCR

    ; handle LF (10) -> end of line
    cmp al, 10
    je EndOfLine

    ; normal character: append to lineBuffer if space left
    mov edx, [lineLen]
    cmp edx, 255  ; leave 1 byte for NUL
    jae SkipStore ; ignore extra chars if too long
    mov [lineBuffer + edx], al
    inc edx
    mov [lineLen], edx

SkipStore:
    inc edi
    dec ecx
    jmp ScanChunk

SkipCR:
    inc edi
    dec ecx
    jmp ScanChunk

EndOfLine:
    ; terminate current line
    mov edx, [lineLen]
    mov byte [lineBuffer + edx], 0

    ; if line isn't empty, process it
    cmp edx, 0
    je LineDone

    push esi
    mov esi, lineBuffer
    call HandleLine
    pop esi

LineDone:
    mov dword [lineLen], 0 ; reset line length
    inc edi
    dec ecx
    jmp ScanChunk

; process last line if not newline-terminated, then print result
EOF:
    ; if there is a partial line at EOF, process it
    mov edx, [lineLen]
    cmp edx, 0
    jle FinishEOF
    mov byte [lineBuffer + edx], 0

    push esi
    mov esi, lineBuffer
    call HandleLine
    pop esi

FinishEOF:
    mov eax, [password]
    call PrintInt

    ; newline after result
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov ecx, newline
    mov edx, 1
    int 0x80

    ; close file and exit
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
    mov ebx, 1    ; direction = +1 for 'R' or anything else
    jmp .after
.left:
    mov ebx, -1   ; direction = -1 for 'L'
.after:
    inc esi       ; skip 'L' or 'R'
    call ParseInt ; EAX = steps

    imul eax, ebx ; EAX = dir * steps

    mov edx, [angle]
    add edx, eax  ; update angle (can be out of range, signed)

    ; normalize edx into [0, 100[ using repeated +/-100 (no division)
NormLoop:
    cmp edx, 0
    jl NormAdd
    cmp edx, 100
    jl NormDone
    sub edx, 100
    jmp NormLoop

NormAdd:
    add edx, 100
    jmp NormLoop

NormDone:
    mov [angle], edx

    cmp edx, 0
    jne .done
    mov eax, [password]
    inc eax
    mov [password], eax
.done:
    ret

; ParseInt: - parse decimal number at [ESI] into EAX
;           - stops at first non-digit
ParseInt:
    xor eax, eax      ; result = 0

.parseLoop:
    mov dl, [esi]
    cmp dl, '0'
    jl .done
    cmp dl, '9'
    jg .done

    sub dl, '0'       ; digit value 0..9
    movzx edx, dl

    imul eax, eax, 10 ; result *= 10
    add eax, edx      ; result += digit

    inc esi
    jmp .parseLoop

.done:
    ret

; PrintInt: print unsigned integer in EAX to stdout
PrintInt:
    mov edi, numberBuffer+15   ; write digits from the end
    mov byte [edi], 0          ; terminator
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
    mov edx, eax               ; tmp = current value
    mov ecx, 0                 ; q = 0

    cmp edx, 10
    jb .lastDigit             ; if < 10, quotient = 0, remainder = edx
.subLoop:
    sub edx, 10
    inc ecx                    ; q++
    cmp edx, 10
    jae .subLoop              ; while tmp >= 10
.lastDigit:
    ; now:
    ;   ecx = quotient
    ;   edx = remainder (0..9)
    add dl, '0'
    mov [edi], dl              ; store digit
    dec edi

    mov eax, ecx               ; eax = quotient
    test eax, eax
    jnz .nextDigit            ; more digits to extract?

    inc edi                    ; move to first digit
.finish:
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov ecx, edi
    mov edx, numberBuffer+15
    sub edx, edi               ; length
    int 0x80
    ret
