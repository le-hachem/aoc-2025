; Advent of Code 2025 - Day 1

global _start

%define SYS_EXIT  1
%define SYS_WRITE 4

section .data
    message: db "Hello World!", 0xA
    messageLen: equ $-message

section .text
_start:
    mov eax, SYS_WRITE
    mov ebx, 1
    mov ecx, message
    mov edx, messageLen
    int 0x80

    mov eax, SYS_EXIT
    xor ebx, ebx
    int 0x80
