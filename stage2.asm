; Jogo de Nave 2D - Assembly x86 com Protected Mode
; Compilar com NASM: nasm -f bin stage2.asm -o stage2.bin
; Executar no DOSBox ou emulador compatível

[BITS 16]
org 0x8000

start:
    cli
    
    ; Habilitar A20
    call enable_a20
    
    ; Carregar GDT
    lgdt [gdt_descriptor]
    
    ; Entrar em Protected Mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ; Jump para código 32-bit
    jmp 0x08:protected_mode_start

enable_a20:
    in al, 0x92
    or al, 2
    out 0x92, al
    ret

; ============= GDT =============
gdt_start:
    dd 0x0
    dd 0x0

gdt_code:
    dw 0xFFFF
    dw 0x0
    db 0x0
    db 10011010b
    db 11001111b
    db 0x0

gdt_data:
    dw 0xFFFF
    dw 0x0
    db 0x0
    db 10010010b
    db 11001111b
    db 0x0

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; ============= CÓDIGO 32-BIT =============
[BITS 32]

VIDEO_MODE equ 0x13
SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200
PLAYER_SIZE equ 8
ENEMY_SIZE equ 8
BULLET_SIZE equ 3
CLOUD_SIZE equ 12
MAX_ENEMIES equ 15
MAX_BULLETS equ 10
MAX_ENEMY_BULLETS equ 20
MAX_CLOUDS equ 8
MAX_ROUNDS equ 20

protected_mode_start:
    ; Configurar segmentos de dados
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    
    ; Voltar para modo real temporariamente para configurar vídeo
    call switch_to_real_mode
    
    ; Modo gráfico
    mov ax, VIDEO_MODE
    int 0x10
    
    ; Voltar para modo protegido
    call switch_to_protected_mode
    
    ; Inicializar jogo
    call init_game

game_loop:
    call check_input
    call update_game
    call draw_game
    
    cmp byte [game_state], 0
    je game_loop
    
    cmp byte [game_state], 1
    je show_game_over
    
    cmp byte [game_state], 2
    je show_victory
    
    jmp game_loop

; ============= TROCA DE MODOS =============
switch_to_real_mode:
    jmp 0x18:real_mode_seg
    
[BITS 16]
real_mode_seg:
    mov ax, 0x20
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    mov eax, cr0
    and eax, 0xFFFFFFFE
    mov cr0, eax
    
    jmp 0x0000:real_mode_start

real_mode_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    ret

switch_to_protected_mode:
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_mode_start2

[BITS 32]
protected_mode_start2:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    ret

; ============= INICIALIZAÇÃO =============
init_game:
    mov byte [player_x], 160
    mov byte [player_y], 180
    mov byte [player_alive], 1
    mov byte [round], 1
    mov word [score], 0
    mov byte [enemies_left], 5
    mov byte [game_state], 0
    mov byte [cloud_speed], 1
    
    call spawn_enemies
    
    xor ecx, ecx
init_bullets:
    mov byte [bullets + ecx], 0
    inc ecx
    cmp ecx, MAX_BULLETS * 4
    jl init_bullets
    
    xor ecx, ecx
init_enemy_bullets:
    mov byte [enemy_bullets + ecx], 0
    inc ecx
    cmp ecx, MAX_ENEMY_BULLETS * 4
    jl init_enemy_bullets
    
    call init_clouds
    ret

init_clouds:
    xor ecx, ecx
init_cloud_loop:
    call random
    and al, 0x7F
    add al, 20
    mov [clouds + ecx], al
    
    call random
    and al, 0x3F
    add al, 20
    mov [clouds + ecx + 1], al
    
    mov byte [clouds + ecx + 2], 1
    
    add ecx, 3
    cmp ecx, MAX_CLOUDS * 3
    jl init_cloud_loop
    ret

spawn_enemies:
    call random
    and al, 0x0F
    cmp al, MAX_ENEMIES
    jle spawn_count_ok
    mov al, MAX_ENEMIES
spawn_count_ok:
    cmp al, 1
    jge spawn_min_ok
    mov al, 1
spawn_min_ok:
    mov [enemies_left], al
    
    xor ecx, ecx
spawn_loop:
    movzx eax, byte [enemies_left]
    cmp ecx, eax
    jge spawn_done
    
    push ecx
    shl ecx, 2
    
    call random
    mov [enemies + ecx], al
    
    call random
    and al, 0x3F
    mov [enemies + ecx + 1], al
    
    mov byte [enemies + ecx + 2], 1
    mov byte [enemies + ecx + 3], 0
    
    pop ecx
    inc ecx
    jmp spawn_loop
spawn_done:
    ret

; ============= INPUT =============
check_input:
    ; Ler porta de teclado
    in al, 0x64
    test al, 1
    jz no_key
    
    in al, 0x60
    
    cmp al, 0x48  ; Seta cima
    je move_up
    cmp al, 0x50  ; Seta baixo
    je move_down
    cmp al, 0x4B  ; Seta esquerda
    je move_left
    cmp al, 0x4D  ; Seta direita
    je move_right
    cmp al, 0x39  ; Espaço
    je shoot
    
    cmp byte [game_state], 0
    je no_key
    
    cmp al, 0x13  ; R
    je restart_game
    cmp al, 0x1F  ; S
    je exit_game
    
no_key:
    ret

move_up:
    cmp byte [player_y], 10
    jle no_key
    sub byte [player_y], 2
    ret

move_down:
    cmp byte [player_y], 190
    jge no_key
    add byte [player_y], 2
    ret

move_left:
    cmp byte [player_x], 10
    jle no_key
    sub byte [player_x], 2
    ret

move_right:
    cmp byte [player_x], 310
    jge no_key
    add byte [player_x], 2
    ret

shoot:
    xor ecx, ecx
shoot_find:
    push ecx
    shl ecx, 2
    cmp byte [bullets + ecx + 2], 0
    pop ecx
    je shoot_found
    inc ecx
    cmp ecx, MAX_BULLETS
    jl shoot_find
    ret
shoot_found:
    push ecx
    shl ecx, 2
    mov al, [player_x]
    mov [bullets + ecx], al
    mov al, [player_y]
    mov [bullets + ecx + 1], al
    mov byte [bullets + ecx + 2], 1
    pop ecx
    ret

restart_game:
    call init_game
    ret

exit_game:
    ; Voltar para modo real e sair
    jmp $

; ============= UPDATE =============
update_game:
    cmp byte [game_state], 0
    jne update_done
    
    call update_bullets
    call update_enemies
    call update_enemy_bullets
    call update_clouds
    call check_collisions
    
update_done:
    ret

update_bullets:
    xor ecx, ecx
update_bullet_loop:
    push ecx
    shl ecx, 2
    cmp byte [bullets + ecx + 2], 0
    je next_bullet
    
    sub byte [bullets + ecx + 1], 3
    
    cmp byte [bullets + ecx + 1], 5
    jl deactivate_bullet
    jmp next_bullet
    
deactivate_bullet:
    mov byte [bullets + ecx + 2], 0
    
next_bullet:
    pop ecx
    inc ecx
    cmp ecx, MAX_BULLETS
    jl update_bullet_loop
    ret

update_enemies:
    xor ecx, ecx
update_enemy_loop:
    push ecx
    shl ecx, 2
    cmp byte [enemies + ecx + 2], 0
    je next_enemy
    
    inc byte [enemies + ecx + 3]
    cmp byte [enemies + ecx + 3], 60
    jl no_enemy_shoot
    
    mov byte [enemies + ecx + 3], 0
    call enemy_shoot
    
no_enemy_shoot:
next_enemy:
    pop ecx
    inc ecx
    cmp ecx, MAX_ENEMIES
    jl update_enemy_loop
    ret

enemy_shoot:
    push ecx
    xor ecx, ecx
enemy_shoot_find:
    push ecx
    shl ecx, 2
    cmp byte [enemy_bullets + ecx + 2], 0
    pop ecx
    je enemy_shoot_found
    inc ecx
    cmp ecx, MAX_ENEMY_BULLETS
    jl enemy_shoot_find
    pop ecx
    ret
enemy_shoot_found:
    push ecx
    shl ecx, 2
    mov ebx, [esp + 4]
    shl ebx, 2
    mov al, [enemies + ebx]
    mov [enemy_bullets + ecx], al
    mov al, [enemies + ebx + 1]
    add al, 10
    mov [enemy_bullets + ecx + 1], al
    mov byte [enemy_bullets + ecx + 2], 1
    pop ecx
    pop ecx
    ret

update_enemy_bullets:
    xor ecx, ecx
update_enemy_bullet_loop:
    push ecx
    shl ecx, 2
    cmp byte [enemy_bullets + ecx + 2], 0
    je next_enemy_bullet
    
    add byte [enemy_bullets + ecx + 1], 2
    
    cmp byte [enemy_bullets + ecx + 1], 195
    jg deactivate_enemy_bullet
    jmp next_enemy_bullet
    
deactivate_enemy_bullet:
    mov byte [enemy_bullets + ecx + 2], 0
    
next_enemy_bullet:
    pop ecx
    inc ecx
    cmp ecx, MAX_ENEMY_BULLETS
    jl update_enemy_bullet_loop
    ret

update_clouds:
    xor ecx, ecx
update_cloud_loop:
    lea eax, [ecx * 3]
    cmp byte [clouds + eax + 2], 0
    je next_cloud
    
    mov bl, [cloud_speed]
    add [clouds + eax + 1], bl
    
    cmp byte [clouds + eax + 1], 200
    jl next_cloud
    
    push ecx
    call random
    pop ecx
    lea eax, [ecx * 3]
    mov [clouds + eax], al
    mov byte [clouds + eax + 1], 0
    
next_cloud:
    inc ecx
    cmp ecx, MAX_CLOUDS
    jl update_cloud_loop
    ret

check_collisions:
    xor ecx, ecx
check_bullets:
    push ecx
    shl ecx, 2
    cmp byte [bullets + ecx + 2], 0
    pop ecx
    je next_bullet_check
    
    xor ebx, ebx
check_enemies:
    push ebx
    push ecx
    shl ebx, 2
    shl ecx, 2
    
    cmp byte [enemies + ebx + 2], 0
    je next_enemy_check
    
    mov al, [bullets + ecx]
    mov dl, [enemies + ebx]
    sub al, dl
    cmp al, ENEMY_SIZE
    jg next_enemy_check
    cmp al, 256 - ENEMY_SIZE
    jl next_enemy_check
    
    mov al, [bullets + ecx + 1]
    mov dl, [enemies + ebx + 1]
    sub al, dl
    cmp al, ENEMY_SIZE
    jg next_enemy_check
    cmp al, 256 - ENEMY_SIZE
    jl next_enemy_check
    
    mov byte [bullets + ecx + 2], 0
    mov byte [enemies + ebx + 2], 0
    dec byte [enemies_left]
    
    cmp byte [enemies_left], 0
    jne next_enemy_check
    
    inc byte [round]
    inc byte [cloud_speed]
    
    cmp byte [round], MAX_ROUNDS + 1
    jge game_won
    
    pop ecx
    pop ebx
    call spawn_enemies
    jmp collision_done
    
game_won:
    mov byte [game_state], 2
    pop ecx
    pop ebx
    ret
    
next_enemy_check:
    pop ecx
    pop ebx
    inc ebx
    cmp ebx, MAX_ENEMIES
    jl check_enemies
    
next_bullet_check:
    inc ecx
    cmp ecx, MAX_BULLETS
    jl check_bullets
    
collision_done:
    xor ecx, ecx
check_enemy_bullets_hit:
    push ecx
    shl ecx, 2
    cmp byte [enemy_bullets + ecx + 2], 0
    pop ecx
    je next_enemy_bullet_check
    
    push ecx
    shl ecx, 2
    mov al, [enemy_bullets + ecx]
    mov dl, [player_x]
    sub al, dl
    cmp al, PLAYER_SIZE
    jg next_enemy_bullet_check2
    cmp al, 256 - PLAYER_SIZE
    jl next_enemy_bullet_check2
    
    mov al, [enemy_bullets + ecx + 1]
    mov dl, [player_y]
    sub al, dl
    cmp al, PLAYER_SIZE
    jg next_enemy_bullet_check2
    cmp al, 256 - PLAYER_SIZE
    jl next_enemy_bullet_check2
    
    mov byte [game_state], 1
    pop ecx
    ret
    
next_enemy_bullet_check2:
    pop ecx
next_enemy_bullet_check:
    inc ecx
    cmp ecx, MAX_ENEMY_BULLETS
    jl check_enemy_bullets_hit
    
    ret

; ============= DESENHO =============
draw_game:
    call clear_screen
    
    cmp byte [game_state], 0
    jne draw_done
    
    call draw_clouds
    call draw_enemies
    call draw_bullets
    call draw_enemy_bullets
    call draw_player
    
draw_done:
    ret

clear_screen:
    mov edi, 0xA0000
    mov ecx, 64000
    xor eax, eax
    rep stosd
    ret

draw_player:
    movzx eax, byte [player_x]
    movzx ebx, byte [player_y]
    mov cl, 15
    call draw_rect
    ret

draw_enemies:
    xor ecx, ecx
draw_enemy_loop:
    push ecx
    shl ecx, 2
    cmp byte [enemies + ecx + 2], 0
    je next_draw_enemy
    
    movzx eax, byte [enemies + ecx]
    movzx ebx, byte [enemies + ecx + 1]
    mov cl, 12
    call draw_rect
    
next_draw_enemy:
    pop ecx
    inc ecx
    cmp ecx, MAX_ENEMIES
    jl draw_enemy_loop
    ret

draw_bullets:
    xor ecx, ecx
draw_bullet_loop:
    push ecx
    shl ecx, 2
    cmp byte [bullets + ecx + 2], 0
    je next_draw_bullet
    
    movzx eax, byte [bullets + ecx]
    movzx ebx, byte [bullets + ecx + 1]
    mov cl, 14
    call draw_pixel
    
next_draw_bullet:
    pop ecx
    inc ecx
    cmp ecx, MAX_BULLETS
    jl draw_bullet_loop
    ret

draw_enemy_bullets:
    xor ecx, ecx
draw_enemy_bullet_loop:
    push ecx
    shl ecx, 2
    cmp byte [enemy_bullets + ecx + 2], 0
    je next_draw_enemy_bullet
    
    movzx eax, byte [enemy_bullets + ecx]
    movzx ebx, byte [enemy_bullets + ecx + 1]
    mov cl, 4
    call draw_pixel
    
next_draw_enemy_bullet:
    pop ecx
    inc ecx
    cmp ecx, MAX_ENEMY_BULLETS
    jl draw_enemy_bullet_loop
    ret

draw_clouds:
    xor ecx, ecx
draw_cloud_loop:
    lea edx, [ecx * 3]
    cmp byte [clouds + edx + 2], 0
    je next_draw_cloud
    
    movzx eax, byte [clouds + edx]
    movzx ebx, byte [clouds + edx + 1]
    mov cl, 7
    call draw_rect
    
next_draw_cloud:
    inc ecx
    cmp ecx, MAX_CLOUDS
    jl draw_cloud_loop
    ret

draw_rect:
    push eax
    push ebx
    push ecx
    push edx
    
    mov dl, PLAYER_SIZE
draw_rect_y:
    mov dh, PLAYER_SIZE
draw_rect_x:
    push eax
    push ebx
    call draw_pixel
    pop ebx
    pop eax
    inc eax
    dec dh
    jnz draw_rect_x
    
    mov eax, [esp + 12]
    inc ebx
    dec dl
    jnz draw_rect_y
    
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

draw_pixel:
    push eax
    push ebx
    push ecx
    
    imul ebx, SCREEN_WIDTH
    add ebx, eax
    add ebx, 0xA0000
    
    mov [ebx], cl
    
    pop ecx
    pop ebx
    pop eax
    ret

show_game_over:
    call clear_screen
    call draw_game_over_text
    call check_input
    jmp show_game_over

show_victory:
    call clear_screen
    call draw_victory_text
    call check_input
    jmp show_victory

draw_game_over_text:
    mov edi, 0xA0000 + (100 * SCREEN_WIDTH) + 80
    mov esi, game_over_msg
    mov cl, 12
draw_go_loop:
    lodsb
    test al, al
    jz draw_go_done
    mov [edi], cl
    add edi, 8
    jmp draw_go_loop
draw_go_done:
    ret

draw_victory_text:
    mov edi, 0xA0000 + (100 * SCREEN_WIDTH) + 80
    mov esi, victory_msg
    mov cl, 10
draw_vic_loop:
    lodsb
    test al, al
    jz draw_vic_done
    mov [edi], cl
    add edi, 8
    jmp draw_vic_loop
draw_vic_done:
    ret

random:
    mov eax, [rand_seed]
    imul eax, 1103515245
    add eax, 12345
    mov [rand_seed], eax
    shr eax, 16
    ret

; ============= DADOS =============
align 4
rand_seed: dd 12345

player_x: db 160
player_y: db 180
player_alive: db 1
round: db 1
enemies_left: db 0
game_state: db 0
cloud_speed: db 1

align 2
score: dw 0

align 4
enemies: times MAX_ENEMIES * 4 db 0
bullets: times MAX_BULLETS * 4 db 0
enemy_bullets: times MAX_ENEMY_BULLETS * 4 db 0
clouds: times MAX_CLOUDS * 3 db 0

game_over_msg: db 'GAME OVER', 0
victory_msg: db 'YOU WON!', 0

times 8192-($-$$) db 0