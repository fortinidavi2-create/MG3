; =====================================================
; Hubble LegacyOS - Kernel (Stage2)
; ORG 0x8000 - Carregado pelo bootloader
; Sistema operacional gráfico com suporte a mouse e apps .hub
; =====================================================

[ORG 0x8000]
[BITS 16]

kernel_start:
    cli
    
    ; Configurar segmentos
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    
    sti
    
    ; Inicializar modo de vídeo VGA 320x200 256 cores
    call init_video_mode
    
    ; Inicializar mouse PS/2
    call init_mouse
    
    ; Desenhar interface principal
    call draw_main_interface
    
    ; Loop principal do sistema
main_loop:
    call check_usb_device
    call update_mouse
    call handle_mouse_click
    
    jmp main_loop

; =====================================================
; Inicializar modo de vídeo VGA 320x200 256 cores
; =====================================================
init_video_mode:
    mov ah, 0x00
    mov al, 0x13        ; Modo 13h - 320x200 256 cores
    int 0x10
    ret

; =====================================================
; Inicializar mouse PS/2
; =====================================================
init_mouse:
    ; Habilitar mouse PS/2
    mov ah, 0xC2
    mov bh, 0x00
    int 0x15
    
    ; Resetar mouse
    mov ax, 0xC201
    int 0x15
    
    ; Definir taxa de amostragem
    mov ax, 0xC203
    mov bh, 0x03        ; 3 = 40 amostras/seg
    int 0x15
    
    ret

; =====================================================
; Desenhar interface principal do Hubble Legacy
; =====================================================
draw_main_interface:
    ; Limpar tela com cor de fundo
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov cx, 64000       ; 320*200 pixels
    mov al, 0x01        ; Cor azul escuro
    rep stosb
    
    ; Desenhar título "Hubble Legacy"
    mov si, title_string
    mov dh, 2           ; Linha
    mov dl, 10          ; Coluna
    call draw_string
    
    ; Desenhar área de apps instalados
    call draw_app_grid
    
    ; Desenhar cursor do mouse
    call draw_mouse_cursor
    
    ret

; =====================================================
; Verificar detecção de pendrive (USB)
; =====================================================
check_usb_device:
    ; Verificar se há dispositivo USB conectado
    mov ah, 0x41        ; Função de verificação USB
    mov bx, 0x55AA
    int 0x13
    jc .no_usb
    
    ; Verificar se há arquivo .hub no pendrive
    call scan_for_hub_file
    cmp al, 0x01
    je .hub_found
    
.no_usb:
    ret
    
.hub_found:
    ; Mostrar diálogo de instalação
    call show_install_dialog
    ret

; =====================================================
; Procurar arquivo .hub no pendrive
; =====================================================
scan_for_hub_file:
    ; Ler diretório raiz do pendrive (drive 0x80)
    mov ah, 0x02        ; Ler setores
    mov al, 1           ; 1 setor
    mov ch, 0           ; Cilindro 0
    mov cl, 2           ; Setor 2
    mov dh, 0           ; Cabeça 0
    mov dl, 0x80        ; Drive
    mov bx, hub_buffer
    int 0x13
    jc .not_found
    
    ; Verificar extensão .hub
    mov si, hub_buffer
    mov di, hub_extension
    mov cx, 4
    repe cmpsb
    je .found
    
.not_found:
    xor al, al
    ret
    
.found:
    mov al, 0x01
    ret

; =====================================================
; Mostrar diálogo de instalação de app
; =====================================================
show_install_dialog:
    ; Desenhar janela de diálogo
    mov ax, 0xA000
    mov es, ax
    
    ; Fundo da janela (cinza)
    mov di, (100 * 320) + 80
    mov cx, 160
    mov dx, 80
    mov al, 0x08
    
.draw_dialog:
    push cx
    push di
    rep stosb
    pop di
    add di, 320
    pop cx
    dec dx
    jnz .draw_dialog
    
    ; Desenhar logo do app
    call draw_app_logo
    
    ; Desenhar nome do app
    mov si, app_name
    mov dh, 14
    mov dl, 15
    call draw_string
    
    ; Botão "Baixar"
    call draw_download_button
    
    ; Botão "Cancelar"
    call draw_cancel_button
    
    ; Aguardar clique
    call wait_dialog_click
    
    ret

; =====================================================
; Desenhar grade de apps instalados
; =====================================================
draw_app_grid:
    mov cx, 0           ; Contador de apps
    mov bx, installed_apps
    
.draw_loop:
    cmp cx, [app_count]
    jge .done
    
    ; Calcular posição do app na grade
    push cx
    mov ax, cx
    xor dx, dx
    mov di, 4
    div di              ; AX = linha, DX = coluna
    
    ; Desenhar ícone do app
    call draw_app_icon
    
    pop cx
    inc cx
    jmp .draw_loop
    
.done:
    ret

; =====================================================
; Desenhar ícone de app
; =====================================================
draw_app_icon:
    ; DX = coluna, AX = linha
    ; Calcular posição na tela
    push dx
    push ax
    
    mov di, ax
    imul di, 320 * 70   ; Altura de cada célula
    add di, 20
    
    pop ax
    pop dx
    
    imul dx, 70         ; Largura de cada célula
    add di, dx
    add di, 10
    
    ; Desenhar quadrado 48x48
    mov ax, 0xA000
    mov es, ax
    mov cx, 48
    mov dx, 48
    mov al, 0x0F        ; Cor branca
    
.draw_icon:
    push cx
    push di
    rep stosb
    pop di
    add di, 320
    pop cx
    dec dx
    jnz .draw_icon
    
    ret

; =====================================================
; Atualizar posição do mouse
; =====================================================
update_mouse:
    mov ax, 0x0003
    int 0x33
    
    ; BX = estado dos botões
    ; CX = posição X
    ; DX = posição Y
    
    mov [mouse_x], cx
    mov [mouse_y], dx
    mov [mouse_buttons], bx
    
    call draw_mouse_cursor
    ret

; =====================================================
; Desenhar cursor do mouse
; =====================================================
draw_mouse_cursor:
    mov ax, 0xA000
    mov es, ax
    
    mov ax, [mouse_y]
    imul ax, 320
    add ax, [mouse_x]
    mov di, ax
    
    ; Desenhar ponteiro simples (5x7 pixels)
    mov cx, 5
    mov al, 0x0F        ; Cor branca
    
.draw_cursor_line:
    mov byte [es:di], al
    add di, 320
    dec cx
    jnz .draw_cursor_line
    
    ret

; =====================================================
; Tratar clique do mouse
; =====================================================
handle_mouse_click:
    ; Verificar se botão esquerdo foi clicado
    test word [mouse_buttons], 0x0001
    jz .no_click
    
    ; Verificar se clicou em algum app
    call check_app_click
    
.no_click:
    ret

; =====================================================
; Verificar se clicou em app
; =====================================================
check_app_click:
    mov cx, 0
    
.check_loop:
    cmp cx, [app_count]
    jge .done
    
    ; Calcular área do app
    push cx
    mov ax, cx
    xor dx, dx
    mov di, 4
    div di
    
    ; Verificar se mouse está dentro da área
    ; (implementação simplificada)
    
    pop cx
    inc cx
    jmp .check_loop
    
.done:
    ret

; =====================================================
; Abrir janela de app
; =====================================================
open_app_window:
    ; Desenhar janela maximizada ou em tamanho normal
    mov ax, 0xA000
    mov es, ax
    
    ; Limpar área da janela
    xor di, di
    mov cx, 64000
    mov al, 0x07        ; Cinza claro
    rep stosb
    
    ; Desenhar barra de título
    call draw_title_bar
    
    ; Botões: fechar, maximizar, minimizar
    call draw_window_buttons
    
    ret

; =====================================================
; Desenhar barra de título da janela
; =====================================================
draw_title_bar:
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov cx, 320 * 20    ; Altura da barra
    mov al, 0x01        ; Azul
    rep stosb
    ret

; =====================================================
; Desenhar botões da janela
; =====================================================
draw_window_buttons:
    ; Botão fechar (X) - canto superior direito
    mov di, 295
    mov al, 0x04        ; Vermelho
    call draw_button
    
    ; Botão maximizar
    mov di, 270
    mov al, 0x02        ; Verde
    call draw_button
    
    ; Botão minimizar
    mov di, 245
    mov al, 0x0E        ; Amarelo
    call draw_button
    
    ret

; =====================================================
; Desenhar botão simples
; =====================================================
draw_button:
    mov cx, 15
    mov dx, 15
    
.draw_btn:
    push cx
    push di
    rep stosb
    pop di
    add di, 320
    pop cx
    dec dx
    jnz .draw_btn
    
    ret

; =====================================================
; Desenhar string na tela
; =====================================================
draw_string:
    ; SI = ponteiro para string
    ; DH = linha, DL = coluna
    push ax
    push bx
    
.print_loop:
    lodsb
    cmp al, 0
    je .done
    
    ; Desenhar caractere (simplificado)
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    
    jmp .print_loop
    
.done:
    pop bx
    pop ax
    ret

; =====================================================
; Desenhar botão de download
; =====================================================
draw_download_button:
    mov di, (140 * 320) + 100
    mov cx, 60
    mov dx, 20
    mov al, 0x02        ; Verde
    
.draw:
    push cx
    push di
    rep stosb
    pop di
    add di, 320
    pop cx
    dec dx
    jnz .draw
    
    ret

; =====================================================
; Desenhar botão de cancelar
; =====================================================
draw_cancel_button:
    mov di, (140 * 320) + 180
    mov cx, 60
    mov dx, 20
    mov al, 0x04        ; Vermelho
    
.draw:
    push cx
    push di
    rep stosb
    pop di
    add di, 320
    pop cx
    dec dx
    jnz .draw
    
    ret

; =====================================================
; Desenhar logo do app
; =====================================================
draw_app_logo:
    mov di, (110 * 320) + 135
    mov cx, 50
    mov dx, 50
    mov al, 0x0F
    
.draw:
    push cx
    push di
    rep stosb
    pop di
    add di, 320
    pop cx
    dec dx
    jnz .draw
    
    ret

; =====================================================
; Aguardar clique no diálogo
; =====================================================
wait_dialog_click:
    call update_mouse
    
    test word [mouse_buttons], 0x0001
    jz wait_dialog_click
    
    ; Verificar se clicou em "Baixar" ou "Cancelar"
    mov ax, [mouse_x]
    mov bx, [mouse_y]
    
    ; Área do botão Baixar: X=100-160, Y=140-160
    cmp ax, 100
    jl .check_cancel
    cmp ax, 160
    jg .check_cancel
    cmp bx, 140
    jl .check_cancel
    cmp bx, 160
    jg .check_cancel
    
    ; Clicou em Baixar
    call install_app
    ret
    
.check_cancel:
    ; Área do botão Cancelar: X=180-240, Y=140-160
    cmp ax, 180
    jl wait_dialog_click
    cmp ax, 240
    jg wait_dialog_click
    cmp bx, 140
    jl wait_dialog_click
    cmp bx, 160
    jg wait_dialog_click
    
    ; Clicou em Cancelar
    ret

; =====================================================
; Instalar app no sistema
; =====================================================
install_app:
    ; Copiar dados do app para memória de apps instalados
    mov si, hub_buffer
    mov di, installed_apps
    mov cx, 512
    rep movsb
    
    ; Incrementar contador de apps
    inc word [app_count]
    
    ; Redesenhar interface
    call draw_main_interface
    
    ret

; =====================================================
; Dados e variáveis
; =====================================================
title_string:       db 'Hubble Legacy OS', 0
app_name:           db 'Novo Aplicativo', 0
hub_extension:      db '.hub'
error_msg:          db 'Este programa nao e valido', 0

; Variáveis do mouse
mouse_x:            dw 160
mouse_y:            dw 100
mouse_buttons:      dw 0

; Variáveis de apps
app_count:          dw 0
installed_apps:     times 4096 db 0
hub_buffer:         times 512 db 0

; Preencher até 512 bytes se necessário
