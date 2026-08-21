;
; PC-8001mkII 59k CP/M-80 BIOS
;

msize:  equ     59
bias:   equ     (msize-20)*1024
ccp:    equ     03400h+bias
bdos:   equ     ccp+0806h
bios:   equ     ccp+1600h
biosbody:       equ     bios+0033h
cdisk:  equ     0004h
iobyte: equ     0003h

si_dat: equ     020h
si_ctl: equ     021h
rs_sel: equ     030h
crtc:   equ     051h
crtcdat:        equ     050h
dma2adr:        equ     064h
dma2cnt:        equ     065h
dmamode:        equ     068h
vram:   equ     0f300h
rowsz:  equ     078h
cols:   equ     050h
rows:   equ     019h

REPEAT_DELAY:   equ     30
REPEAT_RATE:    equ     4

bankreg:        equ     031h

fddin:  equ     0fch
fddout: equ     0fdh
fddpc:  equ     0feh
fddctl: equ     0ffh

fdmode: equ     00fh
ndisks: equ     4
phspt:  equ     8
ramtrk: equ     06000h
systrk: equ     0
syssec: equ     2
sysblk: equ     22
offtrk: equ     5
dsm:    equ     159-offtrk

        org     bios

        jp      boot
wboote:
        jp      wboot
        jp      const
        jp      conin
        jp      conout
        jp      list
        jp      punch
        jp      reader
        jp      home
        jp      seldsk
        jp      settrk
        jp      setsec
        jp      setdma
        jp      read
        jp      write
        jp      listst
        jp      sectran

dpbase:
        defw    0000h,0000h
        defw    0000h,0000h
        defw    dirbf,dpblk
        defw    chk00,all00
dph1:   defw    0000h,0000h
        defw    0000h,0000h
        defw    dirbf,dpblk
        defw    chk01,all01
dph2:   defw    0000h,0000h
        defw    0000h,0000h
        defw    dirbf,dpblk
        defw    chk02,all02
dph3:   defw    0000h,0000h
        defw    0000h,0000h
        defw    dirbf,dpblk
        defw    chk03,all03

dpblk:  defw    16
        defb    4
        defb    15
        defb    1
        defw    dsm
        defw    63
        defb    080h
        defb    000h
        defw    16
        defw    offtrk

boot:   di
        xor     a
        ld      hl,localbeg
        ld      (hl),a
        ld      de,localbeg+1
        ld      bc,localsiz-1
        ldir

        ld      hl,highwork
        ld      (hl),a
        ld      de,highwork+1
        ld      bc,highsiz-1
        ldir

        call    console_init
        ld      a,01h
        ld      (iobyte),a
        call    welcome
        call    fdinit
        xor     a
        ld      (cdisk),a
        jr      gocpm

wboot:  di
        ld      sp,ccp
        ld      a,02h
        out     (bankreg),a

wbflush:
        call    cache_flush
        or      a
        jr      nz,wbflush
        call    fdinit
        xor     a
        ld      (diskno),a
        ld      hl,ccp
        ld      d,systrk
        ld      e,syssec
        ld      b,sysblk
wblp:   ld      a,d
        ld      (track),a
        ld      a,e
        ld      (phsec),a
        push    bc
        push    de
        call    rdphys
        pop     de
        pop     bc
        or      a
        jr      nz,wblp
        inc     e
        ld      a,e
        cp      phspt+1
        jr      c,wbnext
        ld      e,1
        inc     d
wbnext:
        djnz    wblp

gocpm:  ld      a,0c3h
        ld      (0),a
        ld      hl,wboote
        ld      (1),hl
        ld      (5),a
        ld      hl,bdos
        ld      (6),hl
        ld      bc,80h
        call    setdma

        di
        ld      a,(cdisk)
        ld      c,a
        jp      ccp

bootmsg:        equ     0c0c0h
welcome:
        ld      hl,bootmsg
        jr      puts

puts:   ld      a,(hl)
        or      a
        ret     z
        ld      c,a
        call    conout
        inc     hl
        jr      puts

console_init:
        call    serial_init
        call    screen_init
        call    crtinit
        call    cursor_sync
        call    snapshot
        call    copycur
        xor     a
        ld      (cursordirty),a
        ld      (keyvalid),a
        ld      (lastvalid),a
        ld      (relcount),a
        ret

serial_init:
        ld      a,23h     ; RS-232C + 80 cols/monochrome
        out     (rs_sel),a
        xor     a
        out     (si_ctl),a
        out     (si_ctl),a
        out     (si_ctl),a
        ld      a,40h
        out     (si_ctl),a
        ld      a,4eh
        out     (si_ctl),a
        ld      a,37h
        out     (si_ctl),a
        ret

const:
        ld      a,(iobyte)
        and     03h
        cp      01h
        jr      z,const_local
        cp      03h
        jr      z,const_both
        jp      serial_const

; UC1:
const_both:
        push    bc
        push    de
        push    hl
        call    local_const
        or      a
        jr      nz,cboth_yes
        call    serial_const
        or      a
        jr      nz,cboth_yes
        xor     a
        jr      cboth_ret
cboth_yes:
        ld      a,0ffh
cboth_ret:
        pop     hl
        pop     de
        pop     bc
        ret

const_local:
        push    bc
        push    de
        push    hl
        call    local_const
        pop     hl
        pop     de
        pop     bc
        ret

serial_const:
        in      a,(si_ctl)
        and     02h
        jr      z,sconst_none
        ld      a,0ffh
        ret
sconst_none:
        xor     a
        ret

local_const:
        ld      a,(keyvalid)
        or      a
        jp      nz,lconst_yes

        ld      a,(keyseqleft)
        or      a
        jr      z,lconst_physical
        call    keyseq_next
        ld      (keybuf),a
        ld      a,01h
        ld      (keyvalid),a
        jp      lconst_yes

lconst_physical:
        call    snapshot

        ld      a,(lastvalid)
        or      a
        jr      z,lconst_scan
        call    lastkey_down
        or      a
        jr      nz,lconst_held
        ld      a,(relcount)
        inc     a
        ld      (relcount),a
        cp      02h
        jr      c,lconst_scan

        xor     a
        ld      (lastvalid),a
        ld      (relcount),a
        ld      (repframes),a
        jr      lconst_scan

lconst_held:
        xor     a
        ld      (relcount),a

lconst_scan:
        call    newpress
        jr      nc,lconst_new

        ld      a,(lastvalid)
        or      a
        jp      z,lconst_none
        call    lastkey_down
        or      a
        jp      z,lconst_none
        call    frame_tick
        or      a
        jr      z,lconst_none

        ld      a,(repframes)
        dec     a
        ld      (repframes),a
        jr      nz,lconst_none

        ld      a,(lastkey)
        ld      (rawkey),a
        call    raw2ascii
        jr      c,lconst_repeat_cancel
        ld      (keybuf),a
        ld      a,01h
        ld      (keyvalid),a
        ld      a,REPEAT_RATE
        ld      (repframes),a
        call    copycur
        jr      lconst_yes

lconst_repeat_cancel:
        xor     a
        ld      (lastvalid),a
        ld      (relcount),a
        ld      (repframes),a
        call    copycur
        ret

lconst_new:
        ld      (rawkey),a

        ld      a,(lastvalid)
        or      a
        jr      z,lconst_accept
        ld      a,(rawkey)
        ld      b,a
        ld      a,(lastkey)
        cp      b
        jr      z,lconst_skip

lconst_accept:
        ld      a,(rawkey)
        call    raw2ascii
        jr      c,lconst_skip

        ld      (keybuf),a
        ld      a,01h
        ld      (keyvalid),a

        ld      a,(rawkey)
        ld      (lastkey),a
        ld      a,01h
        ld      (lastvalid),a
        xor     a
        ld      (relcount),a
        ld      a,REPEAT_DELAY
        ld      (repframes),a

        in      a,(040h)
        and     020h
        ld      (vstate),a

        call    copycur

lconst_yes:
        ld      a,0ffh
        ret

lconst_skip:
        call    copycur
        xor     a
        ret

lconst_none:
        call    copycur
        xor     a
        ret

keyseq_next:
        ld      hl,(keyseqptr)
        ld      a,(hl)
        inc     hl
        ld      (keyseqptr),hl
        ld      b,a
        ld      a,(keyseqleft)
        dec     a
        ld      (keyseqleft),a
        ld      a,b
        ret

frame_tick:
        in      a,(040h)
        and     020h
        ld      b,a
        ld      a,(vstate)
        cp      b
        jr      z,ft_none
        ld      a,b
        ld      (vstate),a
        or      a
        jr      z,ft_none
        ld      a,0ffh
        ret
ft_none:
        xor     a
        ret

lastkey_down:
        ld      a,(lastkey)
        ld      b,a

        and     07h
        ld      e,a
        ld      c,01h
        or      a
        jr      z,lkd_maskdone
lkd_shift:
        ld      a,c
        rlca
        ld      c,a
        dec     e
        jr      nz,lkd_shift

lkd_maskdone:
        ld      a,b
        rrca
        rrca
        rrca
        and     0fh
        ld      e,a
        ld      d,00h
        ld      hl,kcur
        add     hl,de
        ld      a,(hl)
        and     c
        jr      z,lkd_down
        xor     a
        ret
lkd_down:
        ld      a,0ffh
        ret

conin:
        ld      a,(iobyte)
        and     03h
        cp      01h
        jr      z,conin_local
        cp      03h
        jr      z,conin_both
        jp      serial_in

conin_both:
        push    bc
        push    de
        push    hl

        ld      a,(cursordirty)
        or      a
        jr      z,cboth_wait
        call    cursor_sync
        xor     a
        ld      (cursordirty),a
cboth_wait:
        call    local_const
        or      a
        jr      nz,cboth_local
        call    serial_const
        or      a
        jr      z,cboth_wait

        in      a,(si_dat)
        and     7fh
        jr      cboth_char
cboth_local:
        ld      a,(keybuf)
        push    af
        xor     a
        ld      (keyvalid),a
        pop     af
cboth_char:
        cp      00dh
        jr      nz,cboth_retchar
        push    af
        call    cursor_off
        ld      a,01h
        ld      (cursordirty),a
        pop     af
cboth_retchar:
        pop     hl
        pop     de
        pop     bc
        ret

conin_local:
        push    bc
        push    de
        push    hl

        ld      a,(cursordirty)
        or      a
        jr      z,cinwait
        call    cursor_sync
        xor     a
        ld      (cursordirty),a
cinwait:
        call    local_const
        or      a
        jr      z,cinwait
conin_local_ready:
        ld      a,(keybuf)
        push    af
        xor     a
        ld      (keyvalid),a
        pop     af

        cp      00dh
        jr      nz,cinret
        push    af
        call    cursor_off
        ld      a,01h
        ld      (cursordirty),a
        pop     af
cinret:
        pop     hl
        pop     de
        pop     bc
        ret

conout:
        ld      a,(iobyte)
        and     03h
        cp      01h
        jr      z,local_out
        cp      02h
        jr      z,list
        cp      03h
        jr      z,both_out
        jr      serial_out

both_out:
        push    bc
        push    de
        push    hl
        call    lconout
        pop     hl
        pop     de
        pop     bc
        jr      serial_out

local_out:
        push    bc
        push    de
        push    hl
        call    lconout
        pop     hl
        pop     de
        pop     bc
        ret

list:
        ld      a,(iobyte)
        and     0c0h
        cp      040h
        jr      z,local_out
        jr      serial_out
punch:
        jr      serial_out
reader:
        jr      serial_in

serial_in:
        in      a,(si_ctl)
        and     02h
        jr      z,serial_in
        in      a,(si_dat)
        and     7fh
        ret

serial_out:
        in      a,(si_ctl)
        and     01h
        jr      z,serial_out
        ld      a,c
        out     (si_dat),a
        ret

listst:
        ld      a,(iobyte)
        and     0c0h
        cp      040h
        jr      z,lsready
        in      a,(si_ctl)
        and     01h
        jr      z,lsnone
lsready:
        ld      a,0ffh
        ret
lsnone:
        xor     a
        ret

crtinit:
        di

        ld      a,023h
        out     (rs_sel),a
        ld      a,08h
        out     (040h),a
        call    vsync_wait
        xor     a
        out     (crtc),a
        ld      a,0a0h
        out     (dmamode),a

        xor     a
        out     (dma2adr),a
        ld      a,0f3h
        out     (dma2adr),a

        ld      a,0b7h
        out     (dma2cnt),a
        ld      a,08bh
        out     (dma2cnt),a

        ld      a,0ceh
        out     (crtcdat),a
        ld      a,098h
        out     (crtcdat),a
        ld      a,067h
        out     (crtcdat),a
        ld      a,0deh
        out     (crtcdat),a
        ld      a,013h
        out     (crtcdat),a
        ld      a,043h
        out     (crtc),a
        ld      a,0e4h
        out     (dmamode),a
        ld      a,020h
        out     (crtc),a

        xor     a
        out     (040h),a
        ret

vsync_wait:
vwlow:
        in      a,(040h)
        and     020h
        jr      nz,vwlow
vwhigh:
        in      a,(040h)
        and     020h
        jr      z,vwhigh
        ret

lconout:
        ld      a,(escstate)
        or      a
        jp      nz,ansi_feed
        ld      a,c
        cp      01bh
        jr      nz,lcon_normal
        ld      a,01h
        ld      (escstate),a
        ret
lcon_normal:
        ld      a,c
        cp      008h
        jr      z,outbs
        cp      00ch
        jr      z,outff
        cp      00dh
        jr      z,outcr
        cp      00ah
        jr      z,outlf

        call    curaddr
        ld      (hl),c

        ld      a,(curx)
        inc     a
        cp      cols
        jr      c,outxok

        xor     a
        ld      (curx),a
        jr      lineadv

outxok:
        ld      (curx),a
        jr      cursor_mark

outcr:
        xor     a
        ld      (curx),a
        jr      cursor_mark

outlf:
lineadv:
        ld      a,(cury)
        inc     a
        cp      rows
        jr      c,outyok

        call    scroll
        ld      a,rows-1
outyok:
        ld      (cury),a
        jr      cursor_mark

outbs:
        ld      a,(curx)
        or      a
        ret     z
        dec     a
        ld      (curx),a
        jr      cursor_mark

outff:
        call    cls
        jr      cursor_mark

cursor_mark:
        ld      a,01h
        ld      (cursordirty),a
        ret

ansi_feed:
        cp      01h
        jr      nz,ansi_csi

        ld      a,c
        cp      '7'
        jp      z,ansi_save
        cp      '8'
        jp      z,ansi_restore
        cp      '['
        jp      nz,ansi_abort
        ld      a,02h
        ld      (escstate),a
        xor     a
        ld      (csiarg1),a
        ld      (csiarg2),a
        ret

ansi_csi:
        ld      a,c
        sub     '0'
        cp      10
        jr      c,ansi_digit

        ld      a,c
        cp      ';'
        jp      z,ansi_semicolon
        cp      'm'
        jp      z,ansi_sgr

        ld      a,(escstate)
        cp      04h
        jp      z,ansi_abort

        ld      a,c
        cp      'A'
        jp      z,ansi_up
        cp      'B'
        jp      z,ansi_down
        cp      'C'
        jp      z,ansi_right
        cp      'D'
        jp      z,ansi_left
        cp      'E'
        jp      z,ansi_nextline
        cp      'F'
        jp      z,ansi_prevline
        cp      'G'
        jp      z,ansi_col
        cp      'J'
        jp      z,ansi_j
        cp      'K'
        jp      z,ansi_k
        cp      'H'
        jp      z,ansi_pos
        cp      'f'
        jp      z,ansi_pos
        cp      'd'
        jp      z,ansi_row
        cp      's'
        jp      z,ansi_save
        cp      'u'
        jp      z,ansi_restore
        jp      ansi_abort

ansi_digit:
        ld      b,a
        ld      a,(escstate)
        cp      04h
        ret     z

        sub     02h
        cp      02h
        jp      nc,ansi_abort
        ld      e,a
        ld      d,00h
        ld      hl,csiarg1
        add     hl,de

        ld      a,(hl)
        cp      26
        jr      nc,ansi_digit_sat
        cp      25
        jr      nz,ansi_digit_calc
        ld      a,b
        cp      06h
        jr      nc,ansi_digit_sat
        ld      a,(hl)
ansi_digit_calc:
        add     a,a
        ld      e,a
        add     a,a
        add     a,a
        add     a,e
        add     a,b
        ld      (hl),a
        ret
ansi_digit_sat:
        ld      a,0ffh
        ld      (hl),a
        ret

ansi_semicolon:
        ld      a,(escstate)
        cp      04h
        ret     z
        inc     a
        ld      (escstate),a
        ret

ansi_up:
        ld      a,(csiarg1)
        or      a
        jr      nz,ansi_up_n
        inc     a
ansi_up_n:
        ld      b,a
        ld      a,(cury)
        sub     b
        jr      nc,ansi_move_y
        xor     a
        jr      ansi_move_y

ansi_down:
        ld      a,(csiarg1)
        or      a
        jr      nz,ansi_down_n
        inc     a
ansi_down_n:
        ld      b,a
        ld      a,(cury)
        add     a,b
        jr      c,ansi_down_max
        cp      rows
        jr      c,ansi_move_y
ansi_down_max:
        ld      a,rows-1
ansi_move_y:
        ld      (cury),a
        jp      ansi_move_done

ansi_right:
        ld      a,(csiarg1)
        or      a
        jr      nz,ansi_right_n
        inc     a
ansi_right_n:
        ld      b,a
        ld      a,(curx)
        add     a,b
        jr      c,ansi_right_max
        cp      cols
        jr      c,ansi_move_x
ansi_right_max:
        ld      a,cols-1
ansi_move_x:
        ld      (curx),a
        jp      ansi_move_done

ansi_left:
        ld      a,(csiarg1)
        or      a
        jr      nz,ansi_left_n
        inc     a
ansi_left_n:
        ld      b,a
        ld      a,(curx)
        sub     b
        jr      nc,ansi_move_x
        xor     a
        jr      ansi_move_x

ansi_nextline:
        call    ansi_down
        xor     a
        ld      (curx),a
        ret
ansi_prevline:
        call    ansi_up
        xor     a
        ld      (curx),a
        ret

ansi_col:
        ld      a,(csiarg1)
        or      a
        jr      nz,ansi_col_n
        inc     a
ansi_col_n:
        cp      cols+1
        jr      c,ansi_col_ok2
        ld      a,cols
ansi_col_ok2:
        dec     a
        ld      (curx),a
        jp      ansi_move_done

ansi_row:
        ld      a,(csiarg1)
        or      a
        jr      nz,ansi_row_n
        inc     a
ansi_row_n:
        cp      rows+1
        jr      c,ansi_row_ok2
        ld      a,rows
ansi_row_ok2:
        dec     a
        ld      (cury),a
        jp      ansi_move_done

ansi_save:
        ld      a,(curx)
        ld      (savecurx),a
        ld      a,(cury)
        ld      (savecury),a
        jr      ansi_finish
ansi_restore:
        ld      a,(savecurx)
        ld      (curx),a
        ld      a,(savecury)
        ld      (cury),a
ansi_move_done:
        call    cursor_mark
ansi_finish:
        xor     a
        ld      (escstate),a
        ret

ansi_j:
        ld      a,(csiarg1)
        cp      03h
        jp      nc,ansi_abort
        push    af
        xor     a
        ld      (escstate),a
        pop     af
        or      a
        jr      z,ansi_j0
        cp      01h
        jr      z,ansi_j1

        xor     a
ansi_j2_row:
        cp      rows
        jr      nc,ansi_j_done
        push    af
        call    ansi_blank_row_a
        pop     af
        inc     a
        jr      ansi_j2_row

ansi_j0:
        call    ansi_k0_chars
        ld      a,(cury)
        inc     a
ansi_j0_row:
        cp      rows
        jr      nc,ansi_j_done
        push    af
        call    ansi_blank_row_a
        pop     af
        inc     a
        jr      ansi_j0_row

ansi_j1:
        xor     a
ansi_j1_row:
        ld      b,a
        ld      a,(cury)
        cp      b
        jr      z,ansi_j1_current
        ld      a,b
        push    af
        call    ansi_blank_row_a
        pop     af
        inc     a
        jr      ansi_j1_row
ansi_j1_current:
        call    ansi_k1_chars
ansi_j_done:
        jp      cursor_mark

ansi_k:
        ld      a,(csiarg1)
        cp      03h
        jp      nc,ansi_abort
        push    af
        xor     a
        ld      (escstate),a
        pop     af
        or      a
        jr      z,ansi_k0_chars
        cp      01h
        jr      z,ansi_k1_chars
        ld      a,(cury)
        call    ansi_blank_row_a
        jp      cursor_mark

ansi_k0_chars:
        call    curaddr
        ld      a,cols
        ld      b,a
        ld      a,(curx)
        ld      c,a
        ld      a,b
        sub     c
        ld      b,a
        ld      a,' '
ansi_erase_loop:
        ld      (hl),a
        inc     hl
        djnz    ansi_erase_loop
        ret

ansi_k1_chars:
        ld      a,(cury)
        call    rowaddr_a
        ld      a,(curx)
        inc     a
        ld      b,a
        ld      a,' '
        jr      ansi_erase_loop

rowaddr_a:
        add     a,a
        ld      e,a
        ld      d,00h
        ld      hl,rowtab
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        ret

ansi_blank_row_a:
        call    rowaddr_a
        jp      blankchars

ansi_pos:
        xor     a
        ld      (escstate),a

        ld      a,(csiarg1)
        or      a
        jr      nz,ansi_row_nonzero
        inc     a
ansi_row_nonzero:
        cp      rows+1
        jr      c,ansi_row_ok
        ld      a,rows
ansi_row_ok:
        dec     a
        ld      (cury),a

        ld      a,(csiarg2)
        or      a
        jr      nz,ansi_col_nonzero
        inc     a
ansi_col_nonzero:
        cp      cols+1
        jr      c,ansi_col_ok
        ld      a,cols
ansi_col_ok:
        dec     a
        ld      (curx),a
        jp      cursor_mark

ansi_sgr:
        jp      ansi_finish

ansi_abort:
        xor     a
        ld      (escstate),a
        ret

cursor_off:
        call    vsync_wait
        ld      a,080h
        out     (crtc),a
        ret

cursor_sync:
        call    vsync_wait
        ld      a,081h
        out     (crtc),a
        ld      a,(curx)
        out     (crtcdat),a
        ld      a,(cury)
        out     (crtcdat),a
        ret

curaddr:
        ld      a,(cury)
        add     a,a
        ld      e,a
        ld      d,00h
        ld      hl,rowtab
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        ld      a,(curx)
        ld      e,a
        ld      d,00h
        add     hl,de
        ret

screen_init:
        ld      ix,rowtab
        ld      hl,vram
        ld      a,rows
screen_init_row:
        ld      (ix+0),l
        ld      (ix+1),h
        inc     ix
        inc     ix
        push    af
        call    initrow
        pop     af
        dec     a
        jr      nz,screen_init_row
        xor     a
        ld      (curx),a
        ld      (cury),a
        ret

cls:
        xor     a
cls_chars_row:
        cp      rows
        jr      nc,cls_chars_done
        push    af
        call    ansi_blank_row_a
        pop     af
        inc     a
        jr      cls_chars_row
cls_chars_done:
        xor     a
        ld      (curx),a
        ld      (cury),a
        ret

initrow:
        call    blankchars
        ld      (hl),00h
        inc     hl
        ld      (hl),00h
        inc     hl
        ld      b,19
initrow_attr:
        ld      (hl),cols
        inc     hl
        ld      (hl),00h
        inc     hl
        djnz    initrow_attr
        ret

blankchars:
        ld      (hl),' '
        ld      d,h
        ld      e,l
        inc     de
        ld      bc,cols-1

blank64:
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ld      a,b
        or      c
        cp      15
        jr      nz,blank64

        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ex      de,hl
        ret

scroll:
        ld      hl,vram+rowsz
        ld      de,vram
        ld      a,rows-1
scroll_row:
        ld      bc,cols
scroll_copy16:
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        jp      pe,scroll_copy16

        ld      bc,rowsz-cols
        add     hl,bc
        ex      de,hl
        add     hl,bc
        ex      de,hl

        dec     a
        jr      nz,scroll_row

        ex      de,hl
        jp      blankchars

snapshot:
        in      a,(00h)
        ld      (kcur+0),a
        in      a,(01h)
        ld      (kcur+1),a
        in      a,(02h)
        ld      (kcur+2),a
        in      a,(03h)
        ld      (kcur+3),a
        in      a,(04h)
        ld      (kcur+4),a
        in      a,(05h)
        ld      (kcur+5),a
        in      a,(06h)
        ld      (kcur+6),a
        in      a,(07h)
        ld      (kcur+7),a
        in      a,(08h)
        ld      (kcur+8),a
        in      a,(09h)
        ld      (kcur+9),a
        ret

copycur:
        ld      hl,kcur
        ld      de,kprev
        ld      bc,10
        ldir
        ret

newpress:
        ld      hl,kcur
        ld      de,kprev
        ld      c,00h
        ld      b,10

nploop:
        push    bc
        ld      a,(de)
        ld      b,a
        ld      a,(hl)
        cpl
        and     b
        pop     bc

        push    af
        ld      a,b
        cp      2
        pop     af
        jr      nz,npmaskok
        and     00fh
npmaskok:
        or      a
        jr      nz,npbit

        inc     hl
        inc     de
        ld      a,08h
        add     a,c
        ld      c,a
        djnz    nploop
        scf
        ret

npbit:
        ld      e,00h
npbitlp:
        rrca
        jr      c,npfound
        inc     e
        jr      npbitlp
npfound:
        ld      a,c
        add     a,e
        or      a
        ret

raw2ascii:
        ld      a,(rawkey)
        ld      e,a
        ld      d,00h

        ld      a,(kcur+8)
        bit     7,a             ; CTRL: 0 = pressed
        jr      nz,r2_noctrl
        bit     6,a             ; SHIFT: 0 = pressed
        ld      hl,keymap_ctrl
        jr      nz,r2_lookup
        ld      hl,keymap_ctrlshift
        jr      r2_lookup

r2_noctrl:
        bit     6,a
        ld      hl,keymap_normal
        jr      nz,r2_lookup
        ld      hl,keymap_shift

r2_lookup:
        add     hl,de
        ld      a,(hl)
        cp      KEY_NONE
        jr      z,r2bad
        bit     7,a
        jr      nz,r2sequence
        or      a
        ret

r2sequence:
        sub     080h
        cp      KEYSEQ_COUNT
        jr      nc,r2bad
        add     a,a
        ld      e,a
        ld      d,00h
        ld      hl,keyseq_ptrs
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        ld      a,(hl)
        or      a
        jr      z,r2bad
        ld      b,a
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      (keyseqptr),hl
        dec     b
        ld      a,b
        ld      (keyseqleft),a
        dec     hl
        ld      a,(hl)
        or      a
        ret

r2bad:
        scf
        ret

        include "keymap-pc8001.inc"

home:   ld      c,0
        jr      settrk

seldsk:
        ld      hl,0000h
        ld      a,c
        cp      ndisks
        ret     nc
        ld      (diskno),a

        rlca
        rlca
        rlca
        rlca
        ld      e,a
        ld      d,0
        ld      hl,dpbase
        add     hl,de
        ret

settrk:
        ld      a,c
        ld      (track),a
        ret

setsec:
        ld      a,c
        ld      (sector),a
        ret

sectran:
        ld      h,b
        ld      l,c
        ret

setdma:
        ld      l,c
        ld      h,b
        ld      (dmaad),hl
        ret

ramaddr:
        ld      a,(sector)
        ld      b,a
        and     01h
        jr      z,raeven
        ld      e,080h
        jr      rahi
raeven:
        ld      e,000h
rahi:   ld      a,b
        or      a
        rra
        add     a,060h
        ld      d,a
        ret

cache_get:
        ld      a,(cachev)
        or      a
        jr      z,cgmiss
        ld      a,(cached)
        ld      b,a
        ld      a,(diskno)
        cp      b
        jr      nz,cgmiss
        ld      a,(cachet)
        ld      b,a
        ld      a,(track)
        cp      b
        jr      nz,cgmiss
        xor     a
        ret

cgmiss:
        call    cache_flush
        or      a
        ret     nz
        jr      cache_load

cache_flush:
        ld      a,(cachev)
        or      a
        jr      z,cfok
        ld      a,(cachedirty)
        or      a
        jr      z,cfok
        ld      a,00fh
        call    fcmd
        ld      a,phspt
        call    fdata
        ld      a,(cached)
        call    fdata
        ld      a,(cachet)
        call    fdata
        ld      a,01h
        call    fdata
        ld      a,060h
        call    fdata
        xor     a
        call    fdata
        call    waitio
        and     01h
        jr      nz,cferr
        xor     a
        ld      (cachedirty),a
cfok:   xor     a
        ret
cferr:  ld      a,01h
        ret

cache_load:
        ld      a,00eh
        call    fcmd
        ld      a,phspt
        call    fdata
        ld      a,(diskno)
        call    fdata
        ld      a,(track)
        call    fdata
        ld      a,01h
        call    fdata
        ld      a,060h
        call    fdata
        xor     a
        call    fdata
        call    waitio
        and     01h
        jr      nz,clerr
        ld      a,(diskno)
        ld      (cached),a
        ld      a,(track)
        ld      (cachet),a
        ld      a,01h
        ld      (cachev),a
        xor     a
        ld      (cachedirty),a
        ret
clerr:  xor     a
        ld      (cachev),a
        ld      a,01h
        ret

cache_read128:
        call    ramaddr
        ld      a,015h
        call    fcmd
        ld      a,d
        call    fdata
        ld      a,e
        call    fdata
        xor     a
        call    fdata
        ld      a,080h
        call    fdata
        ld      hl,(dmaad)
        ld      b,64
cr128:  call    hfrecv2
        ld      (hl),d
        inc     hl
        ld      (hl),e
        inc     hl
        djnz    cr128
        xor     a
        ret

cache_write128:
        call    ramaddr
        ld      a,016h
        call    fcmd
        ld      a,d
        call    fdata
        ld      a,e
        call    fdata
        xor     a
        call    fdata
        ld      a,080h
        call    fdata
        ld      hl,(dmaad)
        ld      b,64
cw128:  ld      d,(hl)
        inc     hl
        ld      e,(hl)
        inc     hl
        call    hfsend2
        djnz    cw128
        xor     a
        ret

read:   call    cache_get
        or      a
        ret     nz
        jr      cache_read128

write:  ld      a,c
        ld      (wrtype),a
        call    cache_get
        or      a
        ret     nz
        call    cache_write128
        or      a
        ret     nz
        ld      a,01h
        ld      (cachedirty),a
        ld      a,(wrtype)
        cp      01h
        jr      nz,wrok
        jp      cache_flush
wrok:   xor     a
        ret

fdinit:
        ld      a,91h
        out     (fddctl),a
        xor     a
        ld      (cachev),a
        ld      (cachedirty),a
        call    fcmd
        ld      a,17h
        call    fcmd
        ld      a,fdmode
        jp      fdata

rdphys:
        push    hl
        ld      a,02h
        call    fcmd
        ld      a,01h
        call    fdata
        ld      a,(diskno)
        call    fdata
        ld      a,(track)
        call    fdata
        ld      a,(phsec)
        call    fdata
        call    waitio
        ld      c,a
        and     01h
        jr      nz,rdperr
        ld      a,c
        and     40h
        jr      z,rdperr
        ld      a,03h
        call    fcmd
        pop     hl
        ld      b,00h
rdplp:  call    frecv
        ld      (hl),a
        inc     hl
        djnz    rdplp
        call    waitio
        and     01h
        jr      nz,ioerr
        xor     a
        ret
rdperr:
        pop     hl
ioerr:  ld      a,01h
        ret

wrphys:
        push    hl
        ld      a,01h
        call    fcmd
        ld      a,01h
        call    fdata
        ld      a,(diskno)
        call    fdata
        ld      a,(track)
        call    fdata
        ld      a,(phsec)
        call    fdata
        pop     hl
        ld      b,00h
wrplp:  ld      a,(hl)
        call    fdata
        inc     hl
        djnz    wrplp
        call    waitio
        and     01h
        jr      nz,ioerr
        xor     a
        ret

waitio:
        ld      a,06h
        call    fcmd
        call    frecv
        ld      c,a
        and     80h
        jr      z,waitio
        ld      a,c
        ret

fcmd:   push    af
        ld      a,0fh
        out     (fddctl),a
fcmd1:  in      a,(fddpc)
        and     06h
        cp      02h
        jr      nz,fcmd1
        ld      a,0eh
        out     (fddctl),a
        pop     af
        out     (fddout),a
        ld      a,09h
        out     (fddctl),a
fcmd2:  in      a,(fddpc)
        and     04h
        jr      z,fcmd2
        ld      a,08h
        out     (fddctl),a
fcmd3:  in      a,(fddpc)
        and     04h
        jr      nz,fcmd3
        ret

fdata:  push    af
fdat1:  in      a,(fddpc)
        and     06h
        cp      02h
        jr      nz,fdat1
        pop     af
        out     (fddout),a
        ld      a,09h
        out     (fddctl),a
fdat2:  in      a,(fddpc)
        and     04h
        jr      z,fdat2
        ld      a,08h
        out     (fddctl),a
fdat3:  in      a,(fddpc)
        and     04h
        jr      nz,fdat3
        ret

hfrecv2:
        ld      a,0bh
        out     (fddctl),a
hfr1:   in      a,(fddpc)
        and     01h
        jr      z,hfr1
        ld      a,0ah
        out     (fddctl),a
        in      a,(fddin)
        ld      d,a
        ld      a,0dh
        out     (fddctl),a
hfr2:   in      a,(fddpc)
        and     01h
        jr      nz,hfr2
        in      a,(fddin)
        ld      e,a
        ld      a,0ch
        out     (fddctl),a
        ret

hfsend2:
        in      a,(fddpc)
hfs1:   and     06h
        cp      02h
        jr      z,hfs2
        in      a,(fddpc)
        jr      hfs1
hfs2:   ld      a,d
        out     (fddout),a
        ld      a,09h
        out     (fddctl),a
hfs3:   in      a,(fddpc)
        and     04h
        jr      z,hfs3
        ld      a,e
        out     (fddout),a
        ld      a,08h
        out     (fddctl),a
hfs4:   in      a,(fddpc)
        and     04h
        jr      nz,hfs4
        ret

frecv:  ld      a,0bh
        out     (fddctl),a
frcv1:  in      a,(fddpc)
        and     01h
        jr      z,frcv1
        ld      a,0ah
        out     (fddctl),a
        in      a,(fddin)
        push    af
        ld      a,0dh
        out     (fddctl),a
frcv2:  in      a,(fddpc)
        and     01h
        jr      nz,frcv2
        ld      a,0ch
        out     (fddctl),a
        pop     af
        ret

localbeg:       equ     $

track:          equ     localbeg+0
sector:         equ     track+1
phsec:          equ     sector+1
dmaad:          equ     phsec+1
diskno:         equ     dmaad+2
wrtype:         equ     diskno+1
cachev:         equ     wrtype+1
cachedirty:     equ     cachev+1
cached:         equ     cachedirty+1
cachet:         equ     cached+1

curx:           equ     cachet+1
cury:           equ     curx+1
cursordirty:    equ     cury+1
repframes:      equ     cursordirty+1
vstate:         equ     repframes+1
kcur:           equ     vstate+1
kprev:          equ     kcur+10

escstate:       equ     kprev+10
csiarg1:        equ     escstate+1
csiarg2:        equ     csiarg1+1
savecurx:       equ     csiarg2+1
savecury:       equ     savecurx+1

keyseqptr:      equ     savecury+1
keyseqleft:     equ     keyseqptr+2

localend:       equ     keyseqleft+1
localsiz:       equ     localend-localbeg

highwork:       equ     0feb8h
rowtab:         equ     highwork+0

dirbf:          equ     rowtab+50
all00:          equ     dirbf+128
chk00:          equ     all00+20
all01:          equ     chk00+16
chk01:          equ     all01+20
all02:          equ     chk01+16
chk02:          equ     all02+20
all03:          equ     chk02+16
chk03:          equ     all03+20

rawkey:         equ     chk03+16
keybuf:         equ     rawkey+1
keyvalid:       equ     keybuf+1
lastkey:        equ     keyvalid+1
lastvalid:      equ     lastkey+1
relcount:       equ     lastvalid+1

highend:        equ     relcount+1
highsiz:        equ     highend-highwork
