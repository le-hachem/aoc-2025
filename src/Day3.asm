; Advent of Code 2025 - Day 3

bits 64
default rel

global _start

%define SYS_EXIT 60
%define SYS_WRITE 1

%define STDOUT 1

section .data
    message db "Hello Day 3!", 0xA
    length  equ $-message
    
section .text
_start:
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, message
    mov rdx, length
    syscall

    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall
