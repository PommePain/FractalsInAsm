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
    two:    dd  2
    four:   dd  4
    varA:   dq  0.285
    varB:   dq  0.01
    varI:   db  1
    varX:   dq  0.0
    varY:   dq  0.0
    stock:  dq  0.0
    taille: dd  600
    xmin:   dq  -1.25
    xmax:   dq  1.25
    ymin:   dq  -1.25
    ymax:   dq  1.25
    iteration_max:  db  200
    line:   dd  0
    col:    dd  0
    red:    db  0
    green:  db  0
    blue:   db  0
    baseRed:    db  8
    baseGreen:  db  3
    baseBlue:   db  5
    modulo: dw  256
    rgbColor: dd 0

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
    call    XOpenDisplay	; display creation
    mov     qword[display_name],rax	; rax=name of display

    ; display_name structure
    ; screen = DefaultScreen(display_name);
    mov     rax,qword[display_name]
    mov     eax,dword[rax+0xe0]
    mov     dword[screen],eax

    mov rdi,qword[display_name]
    mov esi,dword[screen]
    call XRootWindow
    mov rbx,rax

    mov rdi,qword[display_name]
    mov rsi,rbx
    mov rdx,10
    mov rcx,10
    mov r8, [taille]	; w
    mov r9, [taille]	; h
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
    mov rdx,0x000000	; pen color
    call XSetForeground

    boucle: ; event management loop
    mov rdi,qword[display_name]
    mov rsi,event
    call XNextEvent

    cmp dword[event],ConfigureNotify	;when the window appears
    je startJulia

    cmp dword[event],KeyPress			;   
    je closeDisplay						; we jump to the label 'closeDisplay' which closes the window
    jmp boucle

startJulia:
    mov dword[line], 0
    mov dword[col], 0
    jmp lineLoop

lineLoop:
    ; For line from 0 to size, line++
    mov eax, dword[line]
    cmp eax, dword[taille]
    jae flush

    mov dword[col], 0
    
    jmp colLoop
endLineLoop:
    inc dword[line]
    jmp lineLoop

colLoop:
    ; For col to size
    mov eax, dword[col]
    cmp eax, dword[taille]
    jae endLineLoop

    ; i = 1
    mov byte[varI], 1

    ; x = xmin+col*(xmax-xmin)/taille
    movsd xmm0, qword[xmax]
    movsd xmm1, qword[xmin]
    cvtsi2sd xmm2, dword[taille]
    cvtsi2sd xmm3, dword[col]
    movsd xmm4, qword[xmin]
    
    subsd xmm0, qword[xmin]    ; xmax - xmin
    mulsd xmm0, xmm3    ; col * (xmax-xmin)
    divsd xmm0, xmm2    ; col * (xmax-xmin) / taille
    addsd xmm0, qword[xmin]    ; xmin + res
    movsd qword[varX], xmm0

    ; y = ymax-line*(ymax-ymin)/taille
    movsd xmm0, qword[ymax]
    movsd xmm1, qword[ymin]
    cvtsi2sd xmm2, dword[taille]
    cvtsi2sd xmm3, dword[line]
    movsd xmm4, qword[ymax]

    subsd xmm0, qword[ymin]
    mulsd xmm0, xmm3
    divsd xmm0, xmm2
    subsd xmm4, xmm0
    movsd qword[varY], xmm4

    jmp whileLoop

whileLoop:
    ; While (i<=iterationmax et (x*x+y*y)<=4)
    mov al, byte[varI]
    cmp al, byte[iteration_max]
    ja afterWhile

    ; (x*x+y*y) <= 4
    movsd xmm0, qword[varX]
    movsd xmm1, qword[varY]
    cvtsi2sd xmm2, dword[four]

    mulsd xmm0, qword[varX]
    mulsd xmm1, qword[varY]
    addsd xmm0, xmm1

    ucomisd xmm0, xmm2
    ja afterWhile

    ; stock = x
    movsd xmm0, qword[varX]
    movsd qword[stock], xmm0

    ; x = x*x-y*y+a
    movsd xmm0, qword[varX]
    movsd xmm1, qword[varY]
    movsd xmm2, qword[varA]

    mulsd xmm0, qword[varX]
    mulsd xmm1, qword[varY]
    subsd xmm0, xmm1
    addsd xmm0, qword[varA]
    movsd qword[varX], xmm0

    ; y = 2*stock*y+b
    cvtsi2sd xmm0, dword[two]
    movsd xmm1, qword[stock]
    movsd xmm2, qword[varY]
    movsd xmm3, qword[varB]

    mulsd xmm0, qword[stock]
    mulsd xmm0, qword[varY]
    addsd xmm0, qword[varB]
    movsd qword[varY], xmm0

    ; i = i + 1
    inc byte[varI]

    jmp whileLoop

afterWhile:
    ; if (i>iterationmax et (x*x+y*y)<=4)
    mov al, byte[varI]
    cmp al, byte[iteration_max]
    jbe drawOtherPixel

    movsd xmm0, qword[varX]
    movsd xmm1, qword[varY]
    cvtsi2sd xmm2, dword[four]

    mulsd xmm0, qword[varX]
    mulsd xmm1, qword[varY]
    addsd xmm0, xmm1
    ucomisd xmm0, xmm2
    ; then draw at the coordinates (col,line) in black
    jbe drawBlackPixel

    ; otherwise draw at the coordinates (col,line) in color (calculated relative to i)
    jmp drawOtherPixel

drawBlackPixel:
    mov rdi,qword[display_name]
    mov rsi,qword[gc]
    mov edx, 0x000000
    call XSetForeground
    jmp drawPixel
drawOtherPixel:
    ; ((baseRed*i)%256,baseGreen*i,(baseBlue*i)%256)
    ; Red
    mov al, byte[baseRed]
    mul byte[varI]
    mov bx, word[modulo]
    xor dx, dx
    div bx
    mov byte[red], dl

    ; Green
    mov al, byte[baseGreen]
    mul byte[varI]
    mov byte[green], al

    ; Blue
    mov al, byte[baseBlue]
    mul byte[varI]
    mov bx, word[modulo]
    xor dx, dx
    div bx
    mov byte[blue], dl

    ; Shifting the values ​​of each color to combine the RGB value into a single variable
    movzx eax, byte[red]
    shl eax, 16
    movzx ax, byte[green]
    shl ax, 8
    mov al, byte[blue]
    mov dword[rgbColor], eax

    mov rdi,qword[display_name]
    mov rsi,qword[gc]
    mov edx, dword[rgbColor]
    call XSetForeground
    jmp drawPixel
drawPixel:
    mov rdi,qword[display_name]
    mov rsi,qword[window]
    mov rdx,qword[gc]
    mov ecx, dword[col]
    mov r8d, dword[line]
    call XDrawPoint
    jmp endColLoop

endColLoop:
    inc dword[col]
    jmp colLoop

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