; Advent of Code 2025 - Day 2

global _start

%define SYS_EXIT  1
%define SYS_WRITE 4

%define STDOUT    1

section .data
    message db "Hello Day 2!", 0xA
    length equ $-message

section .text
_start:
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov ecx, message
    mov edx, length
    int 0x80

    mov eax, SYS_EXIT
    xor ebx, ebx
    int 0x80
