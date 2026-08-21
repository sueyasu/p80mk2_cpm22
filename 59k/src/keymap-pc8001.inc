; PC-8001mkII CP/M keyboard map configuration
; Included by cbios-z80-58k-keyconf.asm.
;
; Each table has one entry for every raw matrix key number 00h..4Fh.
; Modifier combinations are selected before lookup:
;   keymap_normal, keymap_shift, keymap_ctrl, keymap_ctrlshift
;
; Entry values:
;   00h..7Fh : return this byte directly (00h/NUL is valid)
;   80h..    : variable-length sequence token KEYSEQ_*
;   FFh      : no character / unmapped key
;
; The default maps below reproduce the previous BIOS behavior exactly.
; Raw 44h-47h and 49h-4Dh remain unmapped until their physical keys are
; deliberately assigned.

KEY_NONE:       equ     00ffh

; Built-in sequence tokens.  Any key in any modifier table may use these.
KEYSEQ_UP:      equ     080h
KEYSEQ_DOWN:    equ     081h
KEYSEQ_RIGHT:   equ     082h
KEYSEQ_LEFT:    equ     083h
KEYSEQ_HOME:    equ     084h
KEYSEQ_INSERT:  equ     085h
KEYSEQ_DELETE:  equ     086h
KEYSEQ_F1:      equ     087h
KEYSEQ_F2:      equ     088h
KEYSEQ_F3:      equ     089h
KEYSEQ_F4:      equ     08ah
KEYSEQ_F5:      equ     08bh
KEYSEQ_COUNT:   equ     12

keymap_normal:
        defb    30h,31h,32h,33h,34h,35h,36h,37h ; 00h-07h
        defb    38h,39h,2ah,2bh,3dh,2ch,2eh,0dh ; 08h-0Fh
        defb    40h,41h,42h,43h,44h,45h,46h,47h ; 10h-17h
        defb    48h,49h,4ah,4bh,4ch,4dh,4eh,4fh ; 18h-1Fh
        defb    50h,51h,52h,53h,54h,55h,56h,57h ; 20h-27h
        defb    58h,59h,5ah,5bh,5ch,5dh,5eh,2dh ; 28h-2Fh
        defb    30h,31h,32h,33h,34h,35h,36h,37h ; 30h-37h
        defb    38h,39h,3ah,3bh,2ch,2eh,2fh,0ffh ; 38h-3Fh
        defb    0ch,1eh,1ch,08h,0ffh,0ffh,0ffh,0ffh ; 40h-47h
        defb    03h,0ffh,0ffh,0ffh,0ffh,0ffh,20h,1bh ; 48h-4Fh

keymap_shift:
        defb    30h,31h,32h,33h,34h,35h,36h,37h ; 00h-07h
        defb    38h,39h,2ah,2bh,3dh,2ch,2eh,0dh ; 08h-0Fh
        defb    40h,61h,62h,63h,64h,65h,66h,67h ; 10h-17h
        defb    68h,69h,6ah,6bh,6ch,6dh,6eh,6fh ; 18h-1Fh
        defb    70h,71h,72h,73h,74h,75h,76h,77h ; 20h-27h
        defb    78h,79h,7ah,7bh,7ch,7dh,7eh,3dh ; 28h-2Fh
        defb    30h,21h,22h,23h,24h,25h,26h,27h ; 30h-37h
        defb    28h,29h,2ah,2bh,3ch,3eh,3fh,5fh ; 38h-3Fh
        defb    0bh,1fh,1dh,12h,0ffh,0ffh,0ffh,0ffh ; 40h-47h
        defb    03h,0ffh,0ffh,0ffh,0ffh,0ffh,20h,1bh ; 48h-4Fh

keymap_ctrl:
        defb    30h,31h,32h,33h,34h,35h,36h,37h ; 00h-07h
        defb    38h,39h,2ah,2bh,3dh,2ch,2eh,0dh ; 08h-0Fh
        defb    00h,01h,02h,03h,04h,05h,06h,07h ; 10h-17h
        defb    08h,09h,0ah,0bh,0ch,0dh,0eh,0fh ; 18h-1Fh
        defb    10h,11h,12h,13h,14h,15h,16h,17h ; 20h-27h
        defb    18h,19h,1ah,5bh,5ch,5dh,5eh,2dh ; 28h-2Fh
        defb    30h,31h,32h,33h,34h,35h,36h,37h ; 30h-37h
        defb    38h,39h,3ah,3bh,2ch,2eh,2fh,0ffh ; 38h-3Fh
        defb    0ch,1eh,1ch,08h,0ffh,0ffh,0ffh,0ffh ; 40h-47h
        defb    03h,0ffh,0ffh,0ffh,0ffh,0ffh,20h,1bh ; 48h-4Fh

keymap_ctrlshift:
        defb    30h,31h,32h,33h,34h,35h,36h,37h ; 00h-07h
        defb    38h,39h,2ah,2bh,3dh,2ch,2eh,0dh ; 08h-0Fh
        defb    00h,01h,02h,03h,04h,05h,06h,07h ; 10h-17h
        defb    08h,09h,0ah,0bh,0ch,0dh,0eh,0fh ; 18h-1Fh
        defb    10h,11h,12h,13h,14h,15h,16h,17h ; 20h-27h
        defb    18h,19h,1ah,7bh,7ch,7dh,7eh,3dh ; 28h-2Fh
        defb    30h,21h,22h,23h,24h,25h,26h,27h ; 30h-37h
        defb    28h,29h,2ah,2bh,3ch,3eh,3fh,5fh ; 38h-3Fh
        defb    0bh,1fh,1dh,12h,0ffh,0ffh,0ffh,0ffh ; 40h-47h
        defb    03h,0ffh,0ffh,0ffh,0ffh,0ffh,20h,1bh ; 48h-4Fh

; Variable-length sequence descriptors.  First byte is length, followed by
; exactly that many returned bytes.  The pointer-table order must match the
; KEYSEQ_* token values above.  These definitions may also be edited freely.
keyseq_ptrs:
        defw    keyseq_up,keyseq_down,keyseq_right,keyseq_left
        defw    keyseq_home,keyseq_insert,keyseq_delete
        defw    keyseq_f1,keyseq_f2,keyseq_f3,keyseq_f4,keyseq_f5

keyseq_up:      defb    3,01bh,'[','A'
keyseq_down:    defb    3,01bh,'[','B'
keyseq_right:   defb    3,01bh,'[','C'
keyseq_left:    defb    3,01bh,'[','D'
keyseq_home:    defb    3,01bh,'[','H'
keyseq_insert:  defb    4,01bh,'[','2','~'
keyseq_delete:  defb    4,01bh,'[','3','~'
keyseq_f1:      defb    3,01bh,'O','P'
keyseq_f2:      defb    3,01bh,'O','Q'
keyseq_f3:      defb    3,01bh,'O','R'
keyseq_f4:      defb    3,01bh,'O','S'
keyseq_f5:      defb    5,01bh,'[','1','5','~'
