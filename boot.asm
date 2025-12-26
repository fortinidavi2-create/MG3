[ORG 0x7C00]

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [BOOT_DRIVE], dl

    mov ah, 0x0E
    mov al, 'H'
    int 0x10
    mov al, 'e'
    int 0x10
    mov al, 'l'
    int 0x10
    mov al, 'l'
    int 0x10
    mov al, 'o'
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 'B'
    int 0x10
    mov al, 'K'
    int 0x10
    mov al, 'S'
    int 0x10
    mov al, 'X'
    int 0x10

   
    mov ah, 0x02
    mov al, 16         
    mov ch, 0
    mov cl, 2          
    mov dh, 0
    mov dl, [BOOT_DRIVE]
    mov bx, 0x8000

    int 0x13
    jc $

    jmp 0x0000:0x8000

BOOT_DRIVE db 0

times 510 - ($ - $$) db 0
dw 0xAA55