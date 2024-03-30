.586
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "JOCUL VAPORASE",0
area_width EQU 640
area_height EQU 480
area DD 0

counter DD 0 ; numara evenimentele de tip timer
counterOK DD 0
out_m DB "Ati dat click in afara jocului", 13, 10, 0

coord_x_patratel dd 0 ; aici se memoreaza coordonata lui x cand se coloreaza patratelul
; coord_y_patratel dd 0 ; aici se memoreaza coordonata lui y cand se coloreaza patratelul

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20
var DD 2
numarare_albastre DD 0
numarare_rosii DD 0

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

button_x EQU 130
button_y EQU 70
button_size EQU 300

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

;linia are "lungime" pixeli
linie_orizontala macro x, y, lungime, culoare
	local bucla_linie
	mov EAX, y ;EAX=y
	mov EBX, area_width 
	mul EBX ;EAX = y*area_width (EDX=0)
	add EAX, x ;EAX = y*area_width + x
	shl EAX, 2 ;pozitia in vectorul area EAX = (y*area_width + x)*4
	add EAX, area
	mov ECX, lungime
bucla_linie:
	mov dword ptr[EAX], culoare ;in memorie, la adresa data de EAX, punem culoarea
	add EAX, 4
	loop bucla_linie
endm

;linia are "lungime" pixeli
linie_verticala macro x, y, lungime, culoare
	local bucla_linie
	mov EAX, y ;EAX=y
	mov EBX, area_width 
	mul EBX ;EAX = y*area_width (EDX=0)
	add EAX, x ;EAX = y*area_width + x
	shl EAX, 2 ;pozitia in vectorul area EAX = (y*area_width + x)*4
	add EAX, area
	mov ECX, lungime
bucla_linie:
	mov dword ptr[EAX], culoare ;in memorie, la adresa data de EAX, punem culoarea
	add EAX, 4*area_width
	loop bucla_linie
endm

;un macro in care colorez patratelul in care se apasa
colorare_patrat macro x, y, color
local coloana, linie
	push EBX
	mov EDX, 0
	mov EAX, x
	sub EAX, 130   ;x-130
	mov EBX, 30
	div EBX			;EAX = EAX : EBX
	mul EBX         ;EAX = EAX * EBX
	add EAX, 131
	mov coord_x_patratel, EAX   ;valoarea din EAX se pune in lungimea x a patratelului in care se va da click
	pop EBX    ;scoatem EBX de pe stiva
	mov EDX, 0
	;facem acelasi lucru si pt coordonata y a patratelului
	mov EAX, y
	sub EAX, 70
	mov EBX, 25
	div EBX
	mul EBX
	add EAX, 71
	mov EBX, area_width
	mul EBX
	add EAX, coord_x_patratel
	shl EAX, 2    ;echivalent cu :4
	add EAX, area
	mov EDX, 24   ;mai putin cu 1 decat 25 si 30
coloana:
	mov ECX, 29
linie:
	mov dword ptr[EAX], color
	add EAX, 4
	loop linie
	add EAX, (area_width - 29) * 4
	dec EDX
	cmp EDX, 0
	jnz coloana
endm

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	jmp afisare_litere
	
evt_click:
	; mov EAX, [EBP+arg3] ;EAX=y
	; mov EBX, area_width 
	; mul EBX ;EAX = y*area_width (EDX=0)
	; add EAX, [EBP+arg2] ;EAX = y*area_width + x
	; shl EAX, 2 ;pozitia in vectorul area EAX = (y*area_width + x)*4
	; add EAX, area
	; mov dword ptr[EAX], 0FFh  ;in memorie, la adresa data de EAX scriem un pixel albastru
	; EAX - adresa din memorie unde se afla pixelul
	; mov dword ptr[EAX+4], 0FFh ;pixelul din dreapta celui de mai sus
	; mov dword ptr[EAX-4], 0FFh ;stanga
	; mov dword ptr[EAX+4*area_width], 0FFh ;jos
	; mov dword ptr[EAX-4*area_width], 0FFh ;sus
	
	; mov dword ptr[EAX-8*area_width], 0FFh
	; mov dword ptr[EAX+8*area_width], 0FFh
	; mov dword ptr[EAX-8*(area_width-1)], 0FFh
	; mov dword ptr[EAX-8*(area_width+1)], 0FFh
	; mov dword ptr[EAX+8*(area_width+1)], 0FFh
	; mov dword ptr[EAX+8*(area_width-1)], 0FFh
	
	; mov dword ptr[EAX+4*area_width+4], 0FFh
	; mov dword ptr[EAX+4*area_width], 0FFh
	; mov dword ptr[EAX+4*area_width-4], 0FFh
	; mov dword ptr[EAX-4*area_width+4], 0FFh
	; mov dword ptr[EAX-4*area_width-4], 0FFh
	; mov dword ptr[EAX-4*(area_width-2)], 0FFh
	; mov dword ptr[EAX-4*(area_width+2)], 0FFh
	; mov dword ptr[EAX+4*(area_width-2)], 0FFh 
	
	; mov dword ptr[EAX+4*(area_width-3)], 0FFh
	; mov dword ptr[EAX+4*(area_width+3)], 0FFh
	; mov dword ptr[EAX-4*(area_width-3)], 0FFh
	; mov dword ptr[EAX-4*(area_width+3)], 0FFh
	
	;linie_verticala [EBP+arg2], [EBP+arg3], 30, 0FFh ;albastru
	mov EAX, [EBP+arg2]
	cmp EAX, 130
	jle button_fail
	cmp EAX, 430
	jge button_fail
	mov EBX, [EBP+arg3]
	cmp EBX, 70
	jle button_fail
	cmp EBX, 370
	jge button_fail
	
	
	;mai jos am incercat sa fac sa nu se poata da click de doua ori in acelasi patratel
	;daca vede ca deja s a dat click acolo, compara daca e una din culorile rosu sau albastru, adica daca e diferit de alb
	;daca este, nu se mai poate schimba culoarea
	push EAX
	push EBX
	pop EAX   ;interschimbare EAX cu EBX
	;EAX = y 
	pop EBX ;EBX = x
	
	push EBX
	push EAX
	push EDI
	mov EDI, EBX    ;in EDI punem x
	mov EBX, area_width
	mul EBX   ;aici EAX devine y*area_width (EDX = 0)
	add EAX, EDI ;EAX = y*area_width+x
	pop EDI
	shl EAX, 2  ;pozitia in vectorul area EAX = (y*area_width + x) * 4
	; shiftare la stanga cu 2 este echivalenta cu inmultire cu 4
	add EAX, area
	mov ESI, EAX
	pop EBX
	pop EAX
	
	cmp dword ptr[ESI], 0FFh
	je et2
	cmp dword ptr[ESI], 0FF0000h
	je et2
	
	push eax
	rdtsc
	mov EDX, 0
	div var
	pop eax
	cmp edx , 0
	jne et1
	colorare_patrat EAX, EBX, 0FF0000h
	inc numarare_rosii
	inc counterOK
	cmp counterOK, 15
	je afisare_lovite
	jmp et2
	;je et2
	
	et1:
	colorare_patrat EAX, EBX, 0FFh
	inc numarare_albastre
	inc counterOK
	cmp counterOK, 15
	je afisare_ratate
	
	et2:
	; s-a dat click in buton
	; make_text_macro 'O', area, button_x + button_size/2 - 5, button_y + button_size + 10
	; make_text_macro 'K', area, button_x + button_size/2 + 5, button_y + button_size + 10
	mov counterOK, 0
	jmp afisare_lovite 
	
button_fail: 
	;make_text_macro ' ', area, button_x + button_size/2 - 5, button_y + button_size + 10
	;make_text_macro ' ', area, button_x + button_size/2 + 5, button_y + button_size + 10
	jmp afisare_litere

evt_timer:
	inc counter
	inc counterOK 
	cmp counterOK, 15
	je button_fail 
	
afisare_ratate:
	;afisam valoarea counter-ului curent pt a numara de cate ori am ratat (sute, zeci si unitati)
	mov ebx, 10
	mov eax, numarare_albastre
	; cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 540, 270
	; cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 530, 270
	; cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 520, 270
	
afisare_lovite:
	;afisam valoarea counter-ului curent pt a numara de cate ori am nimerit un vaporas (sute, zeci si unitati)
	mov ebx, 10
	mov eax, numarare_rosii
	; cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 540, 160
	; cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 530, 160
	; cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 520, 160	
	
afisare_litere:
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, counter
	; cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 30, 10
	; cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 20, 10
	; cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 10, 10
	
	
	;scriem un mesaj
	make_text_macro 'J', area, 130, 10
	make_text_macro 'O', area, 140, 10
	make_text_macro 'A', area, 150, 10
	make_text_macro 'C', area, 160, 10
	make_text_macro 'A', area, 170, 10
	
	make_text_macro 'V', area, 190, 10
	make_text_macro 'A', area, 200, 10
	make_text_macro 'P', area, 210, 10 
	make_text_macro 'O', area, 220, 10
	make_text_macro 'R', area, 230, 10
	make_text_macro 'A', area, 240, 10
	make_text_macro 'S', area, 250, 10
	make_text_macro 'E', area, 260, 10
	
	make_text_macro 'N', area, 50, 405
	make_text_macro 'E', area, 60, 405
	make_text_macro 'D', area, 70, 405
	make_text_macro 'E', area, 80, 405
	make_text_macro 'S', area, 90, 405
	make_text_macro 'C', area, 100, 405
	make_text_macro 'O', area, 110, 405
	make_text_macro 'P', area, 120, 405
	make_text_macro 'E', area, 130, 405
	make_text_macro 'R', area, 140, 405
	make_text_macro 'I', area, 150, 405
	make_text_macro 'T', area, 160, 405
	make_text_macro 'E', area, 170, 405
	
	make_text_macro 'L', area, 450, 160
	make_text_macro 'O', area, 460, 160
	make_text_macro 'V', area, 470, 160
	make_text_macro 'I', area, 480, 160
	make_text_macro 'T', area, 490, 160
	make_text_macro 'E', area, 500, 160
	
	make_text_macro 'R', area, 450, 270
	make_text_macro 'A', area, 460, 270
	make_text_macro 'T', area, 470, 270
	make_text_macro 'A', area, 480, 270
	make_text_macro 'T', area, 490, 270
	make_text_macro 'E', area, 500, 270
	
	
	
	;CONTUR JOC
	linie_orizontala button_x, button_y, button_size,0
	linie_orizontala button_x, button_y + button_size, button_size,0
	linie_verticala button_x, button_y, button_size,0
	linie_verticala button_x + button_size, button_y, button_size,0
	
	linie_orizontala button_x, button_y - 5, button_size,0
	linie_orizontala button_x, button_y + button_size + 5, button_size,0
	linie_verticala button_x - 5, button_y, button_size,0
	linie_verticala button_x + button_size + 5, button_y, button_size,0
	
	;liniile orizontale
	linie_orizontala button_x, button_y+25, button_size,0
	linie_orizontala button_x, button_y+50, button_size,0
	linie_orizontala button_x, button_y+75, button_size,0
	linie_orizontala button_x, button_y+100, button_size,0
	linie_orizontala button_x, button_y+125, button_size,0
	linie_orizontala button_x, button_y+150, button_size,0
	linie_orizontala button_x, button_y+175, button_size,0
	linie_orizontala button_x, button_y+200, button_size,0
	linie_orizontala button_x, button_y+225, button_size,0
	linie_orizontala button_x, button_y+250, button_size,0
	linie_orizontala button_x, button_y+275, button_size,0
	
	;liniile verticale
	linie_verticala button_x + 30, button_y, button_size,0
	linie_verticala button_x + 60, button_y, button_size,0
	linie_verticala button_x + 90, button_y, button_size,0
	linie_verticala button_x + 120, button_y, button_size,0
	linie_verticala button_x + 150, button_y, button_size,0
	linie_verticala button_x + 180, button_y, button_size,0
	linie_verticala button_x + 210, button_y, button_size,0
	linie_verticala button_x + 240, button_y, button_size,0
	linie_verticala button_x + 270, button_y, button_size,0
final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	; apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
