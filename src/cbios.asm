;
; PC-8001mkII CP/M-80 2.2 BIOS
;

msize   equ     64

bias    equ     (msize-20)*1024
ccp     equ     3400h+bias
bdos    equ     ccp+806h
bios    equ     ccp+1600h
cdisk   equ     0004h
iobyte  equ     0003h

si_dat  equ     020h
si_ctl  equ     021h
rs_sel  equ     030h
crtc    equ     051h
bankreg equ     031h
fddin   equ     0fch
fddout  equ     0fdh
fddpc   equ     0feh
fddctl  equ     0ffh

fdmode  equ     00fh
ndisks  equ     4
phspt   equ     8
ramtrk  equ     06000h
systrk  equ     0
syssec  equ     2
sysblk  equ     22
offtrk  equ     4
dsm     equ     159-offtrk

        org     bios

        jmp     boot
wboote:
        jmp     wboot
        jmp     const
        jmp     conin
        jmp     conout
        jmp     list
        jmp     punch
        jmp     reader
        jmp     home
        jmp     seldsk
        jmp     settrk
        jmp     setsec
        jmp     setdma
        jmp     read
        jmp     write
        jmp     listst
        jmp     sectran

dpbase:
        dw      0000h,0000h
        dw      0000h,0000h
        dw      dirbf,dpblk
        dw      chk00,all00
dph1:
        dw      0000h,0000h
        dw      0000h,0000h
        dw      dirbf,dpblk
        dw      chk01,all01
dph2:
        dw      0000h,0000h
        dw      0000h,0000h
        dw      dirbf,dpblk
        dw      chk02,all02
dph3:
        dw      0000h,0000h
        dw      0000h,0000h
        dw      dirbf,dpblk
        dw      chk03,all03

dpblk:
        dw      16
        db      4
        db      15
        db      1
        dw      dsm
        dw      63
        db      080h
        db      000h
        dw      16
        dw      offtrk

boot:
        di
        call    serini
        call    welcome
        call    fdinit
        xra     a
        sta     iobyte
        sta     cdisk
        jmp     gocpm

wboot:
        di
        lxi     sp,0d000h
        mvi     a,02h
        out     (bankreg),A

wbflush:
        call    cache_flush
        ora     a
        jnz     wbflush
        call    fdinit
        xra     a
        sta     diskno
        lxi     h,ccp
        mvi     d,systrk
        mvi     e,syssec
        mvi     b,sysblk
wblp:
        mov     a,d
        sta     track
        mov     a,e
        sta     phsec
        push    b
        push    d
        call    rdphys
        pop     d
        pop     b
        ora     a
        jnz     wblp
        inr     e
        mov     a,e
        cpi     phspt+1
        jc      wbnext
        mvi     e,1
        inr     d
wbnext:
        dcr     b
        jnz     wblp

gocpm:
        mvi     a,0c3h
        sta     0
        lxi     h,wboote
        shld    1
        sta     5
        lxi     h,bdos
        shld    6
        lxi     b,80h
        call    setdma
        di
        lda     cdisk
        mov     c,a
        jmp     ccp

welcome:
        lxi     h,msgver
        call    puts
        mvi     a,msize
        call    putdec
        lxi     h,msgmach
        call    puts
        ret

puts:
        mov     a,m
        ora     a
        rz
        mov     c,a
        call    conout
        inx     h
        jmp     puts

putdec:
        mvi     b,'0'
pd10:
        cpi     10
        jc      pddone
        sui     10
        inr     b
        jmp     pd10
pddone:
        push    psw
        mov     a,b
        mov     c,a
        call    conout
        pop     psw
        adi     '0'
        mov     c,a
        jmp     conout

msgver:  db     0dh,0ah,'CP/M-80 Version 2.2',0dh,0ah,0
msgmach: db     'k CP/M for NEC PC-8001mkII',0dh,0ah,0

serini:
        mvi     a,20h
        out     (rs_sel),A      ;select RS-232C
        xra     a
        out     (crtc),A        ;disable CRT DMA
        out     (si_ctl),A
        out     (si_ctl),A
        out     (si_ctl),A
        mvi     a,40h
        out     (si_ctl),A
        mvi     a,4eh
        out     (si_ctl),A
        mvi     a,37h
        out     (si_ctl),A
        ret

const:
        in      (si_ctl),A
        ani     02h
        jz      cnone
        mvi     a,0ffh
        ret
cnone:
        xra     a
        ret

conin:
        in      (si_ctl),A
        ani     02h
        jz      conin
        in      (si_dat),A
        ani     7fh
        ret

conout:
        in      (si_ctl),A
        ani     01h
        jz      conout
        mov     a,c
        out     (si_dat),A
        ret

list:
        jmp     conout
punch:
        jmp     conout
reader:
        jmp     conin

listst:
        in      (si_ctl),A
        ani     01h
        jz      lnone
        mvi     a,0ffh
        ret
lnone:
        xra     a
        ret

home:
        mvi     c,0
        jmp     settrk

seldsk:
        lxi     h,0000h
        mov     a,c
        cpi     ndisks
        rnc
        sta     diskno
        rlc
        rlc
        rlc
        rlc
        mov     e,a
        mvi     d,0
        lxi     h,dpbase
        dad     d
        ret

settrk:
        mov     a,c
        sta     track
        ret

setsec:
        mov     a,c
        sta     sector
        ret

sectran:
        mov     h,b
        mov     l,c
        ret

setdma:
        mov     l,c
        mov     h,b
        shld    dmaad
        ret

;
; Convert the CP/M record number (0..15) to an address within the
; 2K track image held in FDD unit RAM at 6000h-67ffh.
; Returns DE = RAMTRK + sector * 128.
;
ramaddr:
        lda     sector
        mov     b,a
        ani     01h
        jz      raeven
        mvi     e,080h
        jmp     rahi
raeven:
        mvi     e,000h
rahi:
        mov     a,b
        ora     a
        rar
        adi     060h
        mov     d,a
        ret

cache_get:
        lda     cachev
        ora     a
        jz      cgmiss
        lda     cached
        mov     b,a
        lda     diskno
        cmp     b
        jnz     cgmiss
        lda     cachet
        mov     b,a
        lda     track
        cmp     b
        jnz     cgmiss
        xra     a
        ret

cgmiss:
        call    cache_flush
        ora     a
        rnz
        call    cache_load
        ret

cache_flush:
        lda     cachev
        ora     a
        jz      cfok
        lda     cachedirty
        ora     a
        jz      cfok
        mvi     a,00fh
        call    fcmd
        mvi     a,phspt
        call    fdata
        lda     cached
        call    fdata
        lda     cachet
        call    fdata
        mvi     a,01h
        call    fdata
        mvi     a,060h
        call    fdata
        xra     a
        call    fdata
        call    waitio
        ani     01h
        jnz     cferr
        xra     a
        sta     cachedirty
cfok:
        xra     a
        ret
cferr:
        mvi     a,01h
        ret

cache_load:
        mvi     a,00eh
        call    fcmd
        mvi     a,phspt
        call    fdata
        lda     diskno
        call    fdata
        lda     track
        call    fdata
        mvi     a,01h
        call    fdata
        mvi     a,060h
        call    fdata
        xra     a
        call    fdata
        call    waitio
        ani     01h
        jnz     clerr
        lda     diskno
        sta     cached
        lda     track
        sta     cachet
        mvi     a,01h
        sta     cachev
        xra     a
        sta     cachedirty
        ret
clerr:  xra     a
        sta     cachev
        mvi     a,01h
        ret

cache_read128:
        call    ramaddr
        mvi     a,015h
        call    fcmd
        mov     a,d
        call    fdata
        mov     a,e
        call    fdata
        xra     a
        call    fdata
        mvi     a,080h
        call    fdata
        lhld    dmaad
        mvi     b,64
cr128:
        call    hfrecv2
        mov     m,d
        inx     h
        mov     m,e
        inx     h
        dcr     b
        jnz     cr128
        xra     a
        ret

cache_write128:
        call    ramaddr
        mvi     a,016h
        call    fcmd
        mov     a,d
        call    fdata
        mov     a,e
        call    fdata
        xra     a
        call    fdata
        mvi     a,080h
        call    fdata
        lhld    dmaad
        mvi     b,64
cw128:
        mov     d,m
        inx     h
        mov     e,m
        inx     h
        call    hfsend2
        dcr     b
        jnz     cw128
        xra     a
        ret

read:
        call    cache_get
        ora     a
        rnz
        call    cache_read128
        ret

write:
        mov     a,c
        sta     wrtype
        call    cache_get
        ora     a
        rnz
        call    cache_write128
        ora     a
        rnz
        mvi     a,01h
        sta     cachedirty
        lda     wrtype
        cpi     01h
        jnz     wrok
        call    cache_flush
        ret
wrok:
        xra     a
        ret

fdinit:
        mvi     a,91h
        out     (fddctl),A
        xra     a
        sta     cachev
        sta     cachedirty
        call    fcmd
        mvi     a,17h
        call    fcmd
        mvi     a,fdmode
        call    fdata
        ret

rdphys:
        push    h
        mvi     a,02h
        call    fcmd
        mvi     a,01h
        call    fdata
        lda     diskno
        call    fdata
        lda     track
        call    fdata
        lda     phsec
        call    fdata
        call    waitio
        mov     c,a
        ani     01h
        jnz     rdperr
        mov     a,c
        ani     40h
        jz      rdperr
        mvi     a,03h
        call    fcmd
        pop     h
        mvi     b,00h
rdplp:
        call    frecv
        mov     m,a
        inx     h
        dcr     b
        jnz     rdplp
        call    waitio
        ani     01h
        jnz     ioerr
        xra     a
        ret
rdperr:
        pop     h
ioerr:
        mvi     a,01h
        ret

wrphys:
        push    h
        mvi     a,01h
        call    fcmd
        mvi     a,01h
        call    fdata
        lda     diskno
        call    fdata
        lda     track
        call    fdata
        lda     phsec
        call    fdata
        pop     h
        mvi     b,00h
wrplp:
        mov     a,m
        call    fdata
        inx     h
        dcr     b
        jnz     wrplp
        call    waitio
        ani     01h
        jnz     ioerr
        xra     a
        ret

waitio:
        mvi     a,06h
        call    fcmd
        call    frecv
        mov     c,a
        ani     80h
        jz      waitio
        mov     a,c
        ret

fcmd:
        push    psw
        mvi     a,0fh
        out     (fddctl),A
fcmd1:
        in      (fddpc),A
        ani     06h
        cpi     02h
        jnz     fcmd1
        mvi     a,0eh
        out     (fddctl),A
        pop     psw
        out     (fddout),A
        mvi     a,09h
        out     (fddctl),A
fcmd2:
        in      (fddpc),A
        ani     04h
        jz      fcmd2
        mvi     a,08h
        out     (fddctl),A
fcmd3:
        in      (fddpc),A
        ani     04h
        jnz     fcmd3
        ret

fdata:
        push    psw
fdat1:
        in      (fddpc),A
        ani     06h
        cpi     02h
        jnz     fdat1
        pop     psw
        out     (fddout),A
        mvi     a,09h
        out     (fddctl),A
fdat2:
        in      (fddpc),A
        ani     04h
        jz      fdat2
        mvi     a,08h
        out     (fddctl),A
fdat3:
        in      (fddpc),A
        ani     04h
        jnz     fdat3
        ret

hfrecv2:
        mvi     a,0bh
        out     (fddctl),A
hfr1:
        in      (fddpc),A
        ani     01h
        jz      hfr1
        mvi     a,0ah
        out     (fddctl),A
        in      (fddin),A
        mov     d,a
        mvi     a,0dh
        out     (fddctl),A
hfr2:
        in      (fddpc),A
        ani     01h
        jnz     hfr2
        in      (fddin),A
        mov     e,a
        mvi     a,0ch
        out     (fddctl),A
        ret

hfsend2:
        in      (fddpc),A
hfs1:
        ani     06h
        cpi     02h
        jz      hfs2
        in      (fddpc),A
        jmp     hfs1
hfs2:
        mov     a,d
        out     (fddout),A
        mvi     a,09h
        out     (fddctl),A
hfs3:
        in      (fddpc),A
        ani     04h
        jz      hfs3
        mov     a,e
        out     (fddout),A
        mvi     a,08h
        out     (fddctl),A
hfs4:
        in      (fddpc),A
        ani     04h
        jnz     hfs4
        ret

frecv:
        mvi     a,0bh
        out     (fddctl),A
frcv1:
        in      (fddpc),A
        ani     01h
        jz      frcv1
        mvi     a,0ah
        out     (fddctl),A
        in      (fddin),A
        push    psw
        mvi     a,0dh
        out     (fddctl),A
frcv2:
        in      (fddpc),A
        ani     01h
        jnz     frcv2
        mvi     a,0ch
        out     (fddctl),A
        pop     psw
        ret

begdat  equ     $
track:  ds      1
sector: ds      1
phsec:  ds      1
dmaad:  ds      2
diskno: ds      1
wrtype: ds      1

cachev:     ds  1    ; 0=invalid, nonzero=valid
cachedirty: ds  1    ; 0=clean, nonzero=needs SAVE DATA
cached:     ds  1    ; drive number of cached track
cachet:     ds  1    ; logical track number

dirbf:  ds      128
all00:  ds      20
chk00:  ds      16
all01:  ds      20
chk01:  ds      16
all02:  ds      20
chk02:  ds      16
all03:  ds      20
chk03:  ds      16

enddat  equ     $
datsiz  equ     $-begdat

        end
