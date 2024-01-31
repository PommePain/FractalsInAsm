; external functions from X11 library
extern XOpenDisplay
extern XDisplayName
extern XCloseDisplay
extern XCreateSimpleWindow
extern XMapWindow
extern XRootWindow
extern XSelectInput
extern XFlush
extern XCreateGC
extern XSetForeground
extern XDrawLine
extern XDrawPoint
extern XNextEvent

; external functions from stdio library (ld-linux-x86-64.so.2)    
extern printf
extern exit

%define	StructureNotifyMask	131072
%define KeyPressMask		1
%define ButtonPressMask		4
%define MapNotify		19
%define KeyPress		2
%define ButtonPress		4
%define Expose			12
%define ConfigureNotify		22
%define CreateNotify 16
%define QWORD	8
%define DWORD	4
%define WORD	2
%define BYTE	1

global main

section .data
    event:  times	24 dq 0
    x1: dq  -2.1
    x2: dq  0.6
    y1: dq  -1.2
    y2: dq  1.2
    limitWhile: dd  4
    x:  dd  0
    y:  dd  0
    image_x: dd 0
    image_y: dd 0
    varI:   dd  0
    zoom:   dq  260.0
    z_r:    dq  0.0
    z_i:    dq  0.0
    c_r:    dq  0.0
    c_i:    dq  0.0
    tmp:    dq  0.0
    rgbColor:   dd  0x0000FF
    red:    db  240
    green:  db  190
    iteration_max:  dd  50
    vWidth: dd  675
    vHeight:    dd  625

section .bss
    display_name:	resq	1
    screen:			resd	1
    depth:         	resd	1
    connection:    	resd	1
    width:         	resd	1
    height:        	resd	1
    window:		resq	1
    gc:		resq	1

section .text
main:
    xor     rdi,rdi
    call    XOpenDisplay	; Création de display
    mov     qword[display_name],rax	; rax=nom du display

    ; display_name structure
    ; screen = DefaultScreen(display_name);
    mov     rax,qword[display_name]
    mov     eax,dword[rax+0xe0]
    mov     dword[screen],eax

    mov rdi,qword[display_name]
    mov esi,dword[screen]
    call XRootWindow
    mov rbx,rax

    ; On définit image_x en faisant en premier la soustraction entre x2 et x1
    movsd xmm0, qword[x2]
    movsd xmm1, qword[x1]
    subsd xmm0, xmm1
    movsd xmm2, qword[zoom]
    mulsd xmm0, xmm2
    cvtsd2si eax, xmm0
    mov dword[image_x], eax       ; Récupération du résultat dans eax

    ; Même principe que ci-dessus mais avec image_y (y2-y1) * zoom
    movsd xmm0, qword[y2]
    movsd xmm1, qword[y1]
    subsd xmm0, xmm1        ; soustraction nombres flottants
    movsd xmm2, qword[zoom]
    mulsd xmm0, xmm2
    cvtsd2si eax, xmm0
    mov dword[image_y], eax

    mov rdi,qword[display_name]
    mov rsi,rbx
    mov rdx,10
    mov rcx,10
    mov r8, [vWidth]	; largeur
    mov r9, [vHeight]	; hauteur
    push 0xFFFFFF	; background  0xRRGGBB
    push 0x00FF00
    push 1
    call XCreateSimpleWindow
    mov qword[window],rax

    mov rdi,qword[display_name]
    mov rsi,qword[window]
    mov rdx,131077 ;131072
    call XSelectInput

    mov rdi,qword[display_name]
    mov rsi,qword[window]
    call XMapWindow

    mov rsi,qword[window]
    mov rdx,0
    mov rcx,0
    call XCreateGC
    mov qword[gc],rax

    mov rdi,qword[display_name]
    mov rsi,qword[gc]
    mov rdx,0x000000
    call XSetForeground

    boucle:
    mov rdi,qword[display_name]
    mov rsi,event
    call XNextEvent

    cmp dword[event],ConfigureNotify
    je startMandel

    cmp dword[event],KeyPress
    je closeDisplay
    jmp boucle

startMandel:
    mov dword[x], 0
    mov dword[y], 0
    jmp xLoop

xLoop:
    ; Pour x = 0, tant que x < image_x par pas de 1
    mov eax, dword[x]
    cmp eax, dword[image_x]
    jae flush

    mov dword[y], 0
    jmp yLoop
endXLoop:
    inc dword[x]
    jmp xLoop

yLoop:
    ; Pour y = 0, tant que y < image_y par pas de 1
    mov eax, dword[y]
    cmp eax, dword[image_y]
    jae endXLoop

    ; c_r = x / zoom + x1
    cvtsi2sd xmm0, dword[x]
    movsd xmm1, qword[zoom]
    movsd xmm2, qword[x1]

    divsd xmm0, xmm1    ; x / zoom
    addsd xmm0, xmm2    ; (x / zoom) + x1
    movsd qword[c_r], xmm0

    ; c_i = y / zoom + y1
    cvtsi2sd xmm0, dword[y]
    movsd xmm1, qword[zoom]
    movsd xmm2, qword[y1]
    
    divsd xmm0, xmm1    ; y / zoom
    addsd xmm0, xmm2    ; (y . zoom) + y1
    movsd qword[c_i], xmm0

    mov qword[z_r], 0
    mov qword[z_i], 0
    mov dword[varI], 0

    jmp doWhileLoop

doWhileLoop:
    ; Def tmp
    movsd xmm0, qword[z_r]
    movsd qword[tmp], xmm0

    ; z_r = z_r * z_r - z_i * z_i + c_r
    movsd xmm0, qword[z_r]
    movsd xmm1, qword[z_i]
    movsd xmm2, qword[c_r]

    mulsd xmm0, qword[z_r]
    mulsd xmm1, qword[z_i]

    subsd xmm0, xmm1
    ; Résultat final
    addsd xmm0, xmm2
    movsd qword[z_r], xmm0

    ; z_i = 2 * z_i * tmp + c_i
    movsd xmm0, qword[z_i]
    movsd xmm1, qword[tmp]
    movsd xmm2, qword[c_i]
    mov eax, 2
    cvtsi2sd xmm3, eax

    mulsd xmm0, xmm3
    mulsd xmm0, xmm1
    ; Résultat final
    addsd xmm0, xmm2
    movsd qword[z_i], xmm0

    ; i = i + 1
    inc dword[varI]

    ; Tant que (z_r*z_r) + (z_i*z_i) < 4
    movsd xmm0, qword[z_r]
    mulsd xmm0, qword[z_r]

    movsd xmm1, qword[z_i]
    mulsd xmm1, qword[z_i]

    addsd xmm0, xmm1

    cvtsi2sd xmm1, dword[limitWhile]
    ucomisd xmm0, xmm1
    jae afterWhile

    mov eax, dword[varI]
    cmp eax, dword[iteration_max]
    jae afterWhile
    
    jmp doWhileLoop

afterWhile:
    mov eax, dword[varI]
    cmp eax, dword[iteration_max]

    je drawBlackPixel
    jmp drawOtherPixel

drawOtherPixel:
    mov eax, dword[varI]
    mov ebx, dword[iteration_max]
    mov ecx, 255
    mul ecx
    div ebx
    mov dword[rgbColor], eax

    mov rdi, qword[display_name]
    mov rsi, qword[gc]
    mov edx, dword[rgbColor]
    call XSetForeground
    jmp drawPixel
drawBlackPixel:
    mov rdi, qword[display_name]
    mov rsi, qword[gc]
    mov edx, 0x000000
    call XSetForeground
    jmp drawPixel
drawPixel:
    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, qword[gc]
    mov ecx, dword[x]
    mov r8d, dword[y]
    call XDrawPoint

    jmp endYLoop

endYLoop:
    inc dword[y]
    jmp yLoop

jmp flush
flush:
mov rdi,qword[display_name]
call XFlush
;jmp boucle
mov rax,34
syscall

closeDisplay:
    mov     rax,qword[display_name]
    mov     rdi,rax
    call    XCloseDisplay
    xor	    rdi,rdi
    call    exit