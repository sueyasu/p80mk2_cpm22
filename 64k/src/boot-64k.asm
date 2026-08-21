;
; PC-8001mkII 64k CP/M-80 cold boot loader
;

        org     0c000h

msize   equ     64

bias    equ     (msize-20)*1024
cbase   equ     03400h+bias
bdos    equ     cbase+0806h
bios    equ     cbase+1600h

sysblk  equ     27
systrk  equ     0
syssec  equ     2

bankreg equ     031h
fddin   equ     0fch
fddout  equ     0fdh
fddpc   equ     0feh
fddctl  equ     0ffh

boot:
        di
        mvi     a,02h
        out     bankreg
        lxi     sp,0d000h

        mvi     a,091h
        out     fddctl
        xra     a
        call    fcmd
        mvi     a,017h
        call    fcmd
        mvi     a,00fh
        call    fdata

        lxi     h,cbase
        mvi     d,systrk
        mvi     e,syssec
        mvi     c,sysblk

rdnext:
rdretry:
        mvi     a,02h
        call    fcmd
        mvi     a,01h
        call    fdata
        xra     a
        call    fdata
        mov     a,d
        call    fdata
        mov     a,e
        call    fdata
        mvi     a,06h
        call    fcmd
        call    frecv
        ani     041h
        cpi     040h
        jnz     rdretry
        mvi     a,03h
        call    fcmd
        mvi     b,00h

rdbyte:
        call    frecv
        mov     m,a
        inx     h
        dcr     b
        jnz     rdbyte
        inr     e
        mov     a,e
        cpi     09h
        jnz     rdnotrk
        mvi     e,01h
        inr     d

rdnotrk:
        dcr     c
        jnz     rdnext
        jmp     bios

fcmd:
        push    psw
        mvi     a,00fh
        out     fddctl

fcmd1:
        in      fddpc
        ani     006h
        cpi     002h
        jnz     fcmd1
        mvi     a,00eh
        out     fddctl
        pop     psw
        out     fddout
        mvi     a,009h
        out     fddctl

fcmd2:
        in      fddpc
        ani     004h
        jz      fcmd2
        mvi     a,008h
        out     fddctl

fcmd3:
        in      fddpc
        ani     004h
        jnz     fcmd3
        ret

fdata:
        push    psw

fdata1:
        in      fddpc
        ani     006h
        cpi     002h
        jnz     fdata1
        pop     psw
        out     fddout
        mvi     a,009h
        out     fddctl

fdata2:
        in      fddpc
        ani     004h
        jz      fdata2
        mvi     a,008h
        out     fddctl

fdata3:
        in      fddpc
        ani     004h
        jnz     fdata3

        ret

frecv:
        mvi     a,00bh
        out     fddctl

frecv1:
        in      fddpc
        ani     001h
        jz      frecv1
        mvi     a,00ah
        out     fddctl
        in      fddin
        push    psw
        mvi     a,00dh
        out     fddctl

frecv2:
        in      fddpc
        ani     001h
        jnz     frecv2
        mvi     a,00ch
        out     fddctl
        pop     psw
        ret

bootend equ     $
        end
