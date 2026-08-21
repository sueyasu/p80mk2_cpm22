;
; PC-8001mkII 59k CP/M-80 cold boot loader
;

        org     0c000h

msize:  equ     59
bias:   equ     (msize-20)*1024
cbase:  equ     03400h+bias
bdos:   equ     cbase+0806h
bios:   equ     cbase+1600h

sysblk: equ     35
systrk: equ     0
syssec: equ     2

bankreg: equ    031h
fddin:   equ    0fch
fddout:  equ    0fdh
fddpc:   equ    0feh
fddctl:  equ    0ffh

boot:
        di
        ld      a,02h
        out     (bankreg),a
        ld      sp,0c000h
        ld      a,091h
        out     (fddctl),a
        xor     a
        call    fcmd
        ld      a,017h
        call    fcmd
        ld      a,00fh
        call    fdata
        ld      hl,cbase
        ld      d,systrk
        ld      e,syssec
        ld      c,sysblk

rdnext:
rdretry:
        ld      a,02h
        call    fcmd
        ld      a,01h
        call    fdata
        xor     a
        call    fdata
        ld      a,d
        call    fdata
        ld      a,e
        call    fdata
        ld      a,06h
        call    fcmd
        call    frecv
        and     041h
        cp      040h
        jr      nz,rdretry
        ld      a,03h
        call    fcmd
        ld      b,00h

rdbyte:
        call    frecv
        ld      (hl),a
        inc     hl
        djnz    rdbyte

        inc     e
        ld      a,e
        cp      09h
        jr      nz,rdnotrk
        ld      e,01h
        inc     d

rdnotrk:
        dec     c
        jr      nz,rdnext
        jp      bios

fcmd:
        push    af
        ld      a,00fh
        out     (fddctl),a
fcmd1:
        in      a,(fddpc)
        and     006h
        cp      002h
        jr      nz,fcmd1
        ld      a,00eh
        out     (fddctl),a
        jr      fsend_ready

fdata:
        push    af
fdata1:
        in      a,(fddpc)
        and     006h
        cp      002h
        jr      nz,fdata1
fsend_ready:
        pop     af
        out     (fddout),a
        ld      a,009h
        out     (fddctl),a
fsend2:
        in      a,(fddpc)
        and     004h
        jr      z,fsend2
        ld      a,008h
        out     (fddctl),a
fsend3:
        in      a,(fddpc)
        and     004h
        jr      nz,fsend3
        ret

frecv:
        ld      a,00bh
        out     (fddctl),a
frecv1:
        in      a,(fddpc)
        and     001h
        jr      z,frecv1
        ld      a,00ah
        out     (fddctl),a
        in      a,(fddin)
        push    af
        ld      a,00dh
        out     (fddctl),a
frecv2:
        in      a,(fddpc)
        and     001h
        jr      nz,frecv2
        ld      a,00ch
        out     (fddctl),a
        pop     af
        ret

bootmsgaddr: equ 0c0c0h
        defs    bootmsgaddr-$

bootmsg:
        defb    0dh,0ah,'CP/M-80 Version 2.2',0dh,0ah
        defb    '59k CP/M for NEC PC-8001mkII',0dh,0ah,0

bootend: equ     $
        end
