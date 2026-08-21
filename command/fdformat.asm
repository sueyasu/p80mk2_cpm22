;
; FDFORMAT.ASM
;
; PC-8001mkII + PC-80S31 compatible FDD formatter
;
; Usage:
;   FDFORMAT A:        CP/M data disk (default)
;   FDFORMAT /S A:     bootable CP/M system disk
;   FDFORMAT -S A:     same as /S
;   FDFORMAT /L A:     low-level format only
;   FDFORMAT -L A:     same as /L
;

        org     0100h

FDDIN   equ     0fch
FDDOUT  equ     0fdh
FDDPC   equ     0feh
FDDCTL  equ     0ffh
BDOS    equ     0005h

MODE2D  equ     00fh
RAMTRK  equ     06000h
TRKLEN  equ     00800h
MAXTRY  equ     600

; System-track handling.
;   SYS_TRKS = 0 : read DPB OFF from the running BIOS automatically
;   SYS_TRKS = n : force n reserved system tracks (1..MAX_SYS_TRKS)
; Increase MAX_SYS_TRKS as well if a larger fixed/automatic value is needed.
SYS_TRKS     equ  0
MAX_SYS_TRKS equ  5

MODE_DATA equ    0
MODE_SYS  equ    1
MODE_LOW  equ    2

start:
        lxi     d,msgtitle
        call    puts
        call    parse_tail
        jnc     parsed
        lxi     d,msgusage
        call    puts
        jmp     exitccp

parsed:
        lda     mode
        cpi     MODE_LOW
        jz      parsed_ready
        call    resolve_sys_tracks
        ora     a
        jnz     systrkerr

parsed_ready:
        call    show_selection
        lxi     d,msgwarn
        call    puts
        mvi     c,1
        call    BDOS
        call    upper
        cpi     'Y'
        jnz     abort
        call    crlf
        lda     mode
        cpi     MODE_SYS
        jnz     do_sync
        lxi     d,msgsave
        call    puts
        call    bios_copy_system
        ora     a
        jnz     biosreaderr
        jmp     cache_safe

do_sync:
        lxi     d,msgsync
        call    puts
        call    bios_sync_cache
        ora     a
        jnz     biosreaderr

cache_safe:
        lxi     d,msginsert1
        call    puts
        lda     drive
        adi     'A'
        call    putc
        lxi     d,msginsert2
        call    puts
        call    wait_return
        call    clear_diag
        mvi     a,091h
        out     FDDCTL
        mvi     a,1
        sta     stage
        xra     a
        call    fcmd
        jc      commfail
        mvi     a,2
        sta     stage
        mvi     a,017h
        call    fcmd
        jc      commfail
        mvi     a,3
        sta     stage
        mvi     a,MODE2D
        call    fdata
        jc      commfail
        lxi     d,msgformat
        call    puts
        mvi     a,4
        sta     stage
        mvi     a,005h
        call    fcmd
        jc      commfail
        mvi     a,5
        sta     stage
        lda     drive
        call    fdata
        jc      commfail

fmt_poll:
        call    counttry
        jc      fmttimeout
        mvi     a,006h
        call    fcmd
        jnc     fmt_cmd_ok
        call    countcmdto
        call    delay
        jmp     fmt_poll

fmt_cmd_ok:
        call    frecv
        jnc     fmt_rsp_ok
        call    countrspto
        call    delay
        jmp     fmt_poll

fmt_rsp_ok:
        sta     finalst
        lda     firstv
        ora     a
        jnz     fmt_first_done
        lda     finalst
        sta     firstst
        mvi     a,1
        sta     firstv
fmt_first_done:
        lda     finalst
        ani     080h
        jz      fmt_not_done
        lda     finalst
        ani     001h
        jnz     fmterr
        jmp     fmt_ok

fmt_not_done:
        call    delay
        jmp     fmt_poll

fmt_ok:
        call    crlf
        lxi     d,msgfmtok
        call    puts

        lda     mode
        cpi     MODE_LOW
        jz      all_done
        cpi     MODE_SYS
        jnz     init_directory
        lxi     d,msgwritesys
        call    puts
        call    write_system_tracks
        ora     a
        jnz     writefail

init_directory:
        lxi     d,msgdir
        call    puts
        call    fill_e5_track
        lxi     h,sysbuf
        lda     systrks
        call    write_track
        jc      writefail

all_done:
        lda     mode
        cpi     MODE_LOW
        jz      done_low
        cpi     MODE_SYS
        jz      done_sys
        lxi     d,msgdone_data
        call    puts
        jmp     before_exit

done_sys:
        lxi     d,msgdone_sys
        call    puts
        jmp     before_exit

done_low:
        lxi     d,msgdone_low
        call    puts

before_exit:
        lda     drive
        ora     a
        jnz     exitccp
        lxi     d,msgrestore
        call    puts
        call    wait_return
        jmp     exitccp

fmterr:
        call    crlf
        lxi     d,msgfmterr
        call    puts
        call    get_error_status
        call    showdiag
        jmp     before_error_exit

fmttimeout:
        call    crlf
        lxi     d,msgfmttimeout
        call    puts
        call    showdiag
        jmp     before_error_exit

commfail:
        call    crlf
        lxi     d,msgcomm
        call    puts
        lda     stage
        adi     '0'
        call    putc
        call    crlf
        jmp     before_error_exit

writefail:
        call    crlf
        lxi     d,msgwritefail
        call    puts
        lda     wrtrack
        call    hex8
        call    crlf
        call    get_error_status
        jmp     before_error_exit

systrkerr:
        lxi     d,msgsystrkerr
        call    puts
        jmp     exitccp

biosreaderr:
        lxi     d,msgbioserr
        call    puts
        jmp     exitccp

abort:
        call    crlf
        lxi     d,msgabort
        call    puts
        jmp     exitccp

before_error_exit:
        lda     drive
        ora     a
        jnz     exitccp
        lxi     d,msgrestore_err
        call    puts
        call    wait_return

exitccp:
        mvi     c,0
        jmp     BDOS

parse_tail:
        mvi     a,0ffh
        sta     drive
        xra     a
        sta     mode
        sta     optseen
        lxi     h,0081h
        lda     0080h
        mov     b,a

pt_loop:
        mov     a,b
        ora     a
        jz      pt_done
        mov     a,m
        cpi     ' '
        jz      pt_skip
        cpi     09h
        jz      pt_skip
        cpi     '/'
        jz      pt_option
        cpi     '-'
        jz      pt_option
        call    upper
        cpi     'A'
        jc      pt_bad
        cpi     'E'
        jnc     pt_bad
        push    psw
        lda     drive
        cpi     0ffh
        jnz     pt_dup_drive
        pop     psw
        sui     'A'
        sta     drive
        inx     h
        dcr     b
        mov     a,b
        ora     a
        jz      pt_loop
        mov     a,m
        cpi     ':'
        jnz     pt_loop
        inx     h
        dcr     b
        jmp     pt_loop

pt_dup_drive:
        pop     psw
        jmp     pt_bad

pt_option:
        inx     h
        dcr     b
        mov     a,b
        ora     a
        jz      pt_bad
        mov     a,m
        call    upper
        mov     c,a
        lda     optseen
        ora     a
        jnz     pt_bad
        mov     a,c
        cpi     'S'
        jz      pt_set_sys
        cpi     'L'
        jz      pt_set_low
        jmp     pt_bad

pt_set_sys:
        mvi     a,MODE_SYS
        sta     mode
        jmp     pt_opt_done

pt_set_low:
        mvi     a,MODE_LOW
        sta     mode

pt_opt_done:
        mvi     a,1
        sta     optseen
        inx     h
        dcr     b
        jmp     pt_loop

pt_skip:
        inx     h
        dcr     b
        jmp     pt_loop

pt_done:
        lda     drive
        cpi     0ffh
        jz      pt_bad
        ora     a
        ret

pt_bad:
        stc
        ret

upper:
        cpi     'a'
        rc
        cpi     'z'+1
        rnc
        ani     05fh
        ret

show_selection:
        lxi     d,msgdrive_sel
        call    puts
        lda     drive
        adi     'A'
        call    putc
        mvi     a,':'
        call    putc
        lxi     d,msgmode
        call    puts
        lda     mode
        cpi     MODE_SYS
        jz      ss_sys
        cpi     MODE_LOW
        jz      ss_low
        lxi     d,msgmode_data
        jmp     puts
ss_sys:
        lxi     d,msgmode_sys
        jmp     puts
ss_low:
        lxi     d,msgmode_low
        jmp     puts

resolve_sys_tracks:
        mvi     a,SYS_TRKS
        ora     a
        jnz     rst_check

        mvi     c,0
        call    bios_seldsk
        mov     a,h
        ora     l
        jz      rst_err

        lxi     d,10
        dad     d
        mov     e,m
        inx     h
        mov     d,m
        xchg

        lxi     d,13
        dad     d
        mov     b,m
        inx     h
        mov     a,m
        ora     a
        jnz     rst_err
        mov     a,b

rst_check:
        ora     a
        jz      rst_err
        cpi     MAX_SYS_TRKS+1
        jnc     rst_err
        sta     systrks
        xra     a
        ret

rst_err:
        mvi     a,1
        ret

bios_seldsk:
        lhld    0001h
        lxi     d,24
        dad     d
        pchl

bios_settrk:
        lhld    0001h
        lxi     d,27
        dad     d
        pchl

bios_setsec:
        lhld    0001h
        lxi     d,30
        dad     d
        pchl

bios_setdma:
        lhld    0001h
        lxi     d,33
        dad     d
        pchl

bios_read:
        lhld    0001h
        lxi     d,36
        dad     d
        pchl

bios_read_one:
        lda     biotrk
        mov     c,a
        call    bios_settrk

        lda     biosec
        mov     c,a
        call    bios_setsec

        lhld    bioptr
        mov     b,h
        mov     c,l
        call    bios_setdma

        call    bios_read
        ret

bios_sync_cache:
        mvi     c,0
        call    bios_seldsk
        mov     a,h
        ora     l
        jz      bsc_err
        lxi     h,sysbuf
        shld    bioptr
        xra     a
        sta     biotrk
        sta     biosec
        call    bios_read_one
        ora     a
        jnz     bsc_err
        lxi     h,sysbuf+128
        shld    bioptr
        mvi     a,1
        sta     biotrk
        xra     a
        sta     biosec
        call    bios_read_one
        ora     a
        jnz     bsc_err
        xra     a
        ret
bsc_err:
        mvi     a,1
        ret

bios_copy_system:
        mvi     c,0
        call    bios_seldsk
        mov     a,h
        ora     l
        jz      bcs_err
        lxi     h,sysbuf
        shld    bioptr
        xra     a
        sta     biotrk

bcs_track:
        xra     a
        sta     biosec

bcs_sector:
        call    bios_read_one
        ora     a
        jnz     bcs_err
        lhld    bioptr
        lxi     d,128
        dad     d
        shld    bioptr
        lda     biosec
        inr     a
        sta     biosec
        cpi     16
        jc      bcs_sector
        lda     biotrk
        inr     a
        sta     biotrk
        mov     b,a
        lda     systrks
        cmp     b
        jnz     bcs_track
        xra     a
        ret
bcs_err:
        mvi     a,1
        ret

write_system_tracks:
        lxi     h,sysbuf
        xra     a
        sta     wrtrack
        lda     systrks
        sta     sysleft

wst_loop:
        lda     wrtrack
        call    write_track
        rc
        lda     wrtrack
        inr     a
        sta     wrtrack
        lda     sysleft
        dcr     a
        sta     sysleft
        jnz     wst_loop
        xra     a
        ret

fill_e5_track:
        lxi     h,sysbuf
        lxi     b,TRKLEN
        mvi     d,0e5h
fe5_loop:
        mov     m,d
        inx     h
        dcx     b
        mov     a,b
        ora     c
        jnz     fe5_loop
        ret

write_track:
        sta     wrtrack
        push    h
        lxi     d,RAMTRK
        lxi     b,TRKLEN
        call    hsrecvmem
        jc      wt_fail_pop
        pop     h
        lxi     d,TRKLEN
        dad     d
        push    h
        mvi     a,00fh
        call    fcmd
        jc      wt_fail_saved
        mvi     a,8
        call    fdata
        jc      wt_fail_saved
        lda     drive
        call    fdata
        jc      wt_fail_saved
        lda     wrtrack
        call    fdata
        jc      wt_fail_saved
        mvi     a,1
        call    fdata
        jc      wt_fail_saved
        mvi     a,060h
        call    fdata
        jc      wt_fail_saved
        xra     a
        call    fdata
        jc      wt_fail_saved
        call    chkio
        jc      wt_fail_saved
        pop     h
        ora     a
        ret

wt_fail_pop:
        pop     h
        stc
        ret
wt_fail_saved:
        pop     h
        stc
        ret

hsrecvmem:
        mov     a,c
        ani     001h
        jnz     hsm_bad
        mov     a,b
        ora     c
        jz      hsm_bad
        mvi     a,016h
        call    fcmd
        rc
        mov     a,d
        call    fdata
        rc
        mov     a,e
        call    fdata
        rc
        mov     a,b
        call    fdata
        rc
        mov     a,c
        call    fdata
        rc
        call    hssendbuf
        ret
hsm_bad:
        stc
        ret

hssendbuf:
        mov     a,b
        ora     c
        jz      hsb_bad
        mov     a,c
        ani     001h
        jnz     hsb_bad
hssb_loop:
        mov     d,m
        inx     h
        mov     e,m
        inx     h
        call    hfsend2
        rc
        dcx     b
        dcx     b
        mov     a,b
        ora     c
        jnz     hssb_loop
        ora     a
        ret
hsb_bad:
        stc
        ret

hfsend2:
        push    b
        lxi     b,0ffffh
hfs_rfd:
        in      FDDPC
        ani     006h
        cpi     002h
        jz      hfs_ready
        dcx     b
        mov     a,b
        ora     c
        jnz     hfs_rfd
        pop     b
        stc
        ret
hfs_ready:
        mov     a,d
        out     FDDOUT
        mvi     a,009h
        out     FDDCTL
        lxi     b,0ffffh
hfs_dachi:
        in      FDDPC
        ani     004h
        jnz     hfs_second
        dcx     b
        mov     a,b
        ora     c
        jnz     hfs_dachi
        mvi     a,008h
        out     FDDCTL
        pop     b
        stc
        ret
hfs_second:
        mov     a,e
        out     FDDOUT
        mvi     a,008h
        out     FDDCTL
        lxi     b,0ffffh
hfs_daclo:
        in      FDDPC
        ani     004h
        jz      hfs_done
        dcx     b
        mov     a,b
        ora     c
        jnz     hfs_daclo
        pop     b
        stc
        ret
hfs_done:
        pop     b
        ora     a
        ret

chkio:
        mvi     a,006h
        call    fcmd
        rc
        call    frecv
        rc
        sta     lastres
        ani     001h
        jz      cio_ok
        stc
        ret
cio_ok:
        ora     a
        ret

get_error_status:
        mvi     a,013h
        call    fcmd
        jc      ges_unavail
        lxi     h,errbuf
        mvi     b,8
ges_loop:
        call    frecv
        jc      ges_unavail
        mov     m,a
        inx     h
        dcr     b
        jnz     ges_loop

        lxi     d,msgestatus
        call    puts
        lxi     h,errbuf
        mvi     b,8
ges_print:
        mov     a,m
        call    hex8
        mvi     a,' '
        call    putc
        inx     h
        dcr     b
        jnz     ges_print
        call    crlf
        ret
ges_unavail:
        lxi     d,msgerrto
        call    puts
        ret

clear_diag:
        xra     a
        sta     firstv
        sta     firstst
        sta     finalst
        sta     trycnt
        sta     trycnt+1
        sta     cmdto
        sta     cmdto+1
        sta     rspto
        sta     rspto+1
        ret

counttry:
        lhld    trycnt
        inx     h
        shld    trycnt
        lxi     d,MAXTRY
        mov     a,h
        cmp     d
        jc      ctok
        jnz     ctto
        mov     a,l
        cmp     e
        jc      ctok
ctto:
        stc
        ret
ctok:
        ora     a
        ret

countcmdto:
        lhld    cmdto
        inx     h
        shld    cmdto
        ret

countrspto:
        lhld    rspto
        inx     h
        shld    rspto
        ret

showdiag:
        lxi     d,msgfirst
        call    puts
        lda     firstv
        ora     a
        jz      sdnone
        lda     firstst
        call    hex8
        jmp     sdfinal
sdnone:
        mvi     a,'-'
        call    putc
        mvi     a,'-'
        call    putc
sdfinal:
        lxi     d,msgfinal
        call    puts
        lda     finalst
        call    hex8
        lxi     d,msgtries
        call    puts
        lhld    trycnt
        call    hex16
        lxi     d,msgcmdto
        call    puts
        lhld    cmdto
        call    hex16
        lxi     d,msgrspto
        call    puts
        lhld    rspto
        call    hex16
        call    crlf
        ret

delay:
        push    b
        lxi     b,0800h
delay1:
        dcx     b
        mov     a,b
        ora     c
        jnz     delay1
        pop     b
        ret

fcmd:
        push    b
        push    psw
        mvi     a,00fh
        out     FDDCTL
        lxi     b,0ffffh
fc1:
        in      FDDPC
        ani     006h
        cpi     002h
        jz      fcrdy
        dcx     b
        mov     a,b
        ora     c
        jnz     fc1
        mvi     a,00eh
        out     FDDCTL
        pop     psw
        pop     b
        stc
        ret
fcrdy:
        mvi     a,00eh
        out     FDDCTL
        pop     psw
        out     FDDOUT
        mvi     a,009h
        out     FDDCTL
        lxi     b,0ffffh
fc2:
        in      FDDPC
        ani     004h
        jnz     fc2ok
        dcx     b
        mov     a,b
        ora     c
        jnz     fc2
        jmp     fcabort
fc2ok:
        mvi     a,008h
        out     FDDCTL
        lxi     b,0ffffh
fc3:
        in      FDDPC
        ani     004h
        jz      fcok
        dcx     b
        mov     a,b
        ora     c
        jnz     fc3
fcabort:
        mvi     a,008h
        out     FDDCTL
        pop     b
        stc
        ret
fcok:
        pop     b
        ora     a
        ret

fdata:
        push    b
        push    psw
        lxi     b,0ffffh
fd1:
        in      FDDPC
        ani     006h
        cpi     002h
        jz      fdrdy
        dcx     b
        mov     a,b
        ora     c
        jnz     fd1
        pop     psw
        pop     b
        stc
        ret
fdrdy:
        pop     psw
        out     FDDOUT
        mvi     a,009h
        out     FDDCTL
        lxi     b,0ffffh
fd2:
        in      FDDPC
        ani     004h
        jnz     fd2ok
        dcx     b
        mov     a,b
        ora     c
        jnz     fd2
        jmp     fdabort
fd2ok:
        mvi     a,008h
        out     FDDCTL
        lxi     b,0ffffh
fd3:
        in      FDDPC
        ani     004h
        jz      fdok
        dcx     b
        mov     a,b
        ora     c
        jnz     fd3
fdabort:
        mvi     a,008h
        out     FDDCTL
        pop     b
        stc
        ret
fdok:
        pop     b
        ora     a
        ret

frecv:
        push    b
        mvi     a,00bh
        out     FDDCTL
        lxi     b,0ffffh
fr1:
        in      FDDPC
        ani     001h
        jnz     frhave
        dcx     b
        mov     a,b
        ora     c
        jnz     fr1
        mvi     a,00ah
        out     FDDCTL
        pop     b
        stc
        ret
frhave:
        mvi     a,00ah
        out     FDDCTL
        in      FDDIN
        push    psw
        mvi     a,00dh
        out     FDDCTL
        lxi     b,0ffffh
fr2:
        in      FDDPC
        ani     001h
        jz      frok
        dcx     b
        mov     a,b
        ora     c
        jnz     fr2
        mvi     a,00ch
        out     FDDCTL
        pop     psw
        pop     b
        stc
        ret
frok:
        mvi     a,00ch
        out     FDDCTL
        pop     psw
        pop     b
        ora     a
        ret

puts:
        push    b
        push    d
        push    h
        mvi     c,9
        call    BDOS
        pop     h
        pop     d
        pop     b
        ret

putc:
        push    b
        push    d
        push    h
        mov     e,a
        mvi     c,2
        call    BDOS
        pop     h
        pop     d
        pop     b
        ret

crlf:
        mvi     a,0dh
        call    putc
        mvi     a,0ah
        jmp     putc

wait_return:
        lxi     d,msgpress
        call    puts
wr_loop:
        mvi     c,1
        call    BDOS
        cpi     0dh
        jnz     wr_loop
        call    crlf
        ret

hex16:
        mov     a,h
        call    hex8
        mov     a,l
        jmp     hex8

hex8:
        push    psw
        rrc
        rrc
        rrc
        rrc
        ani     00fh
        call    hexnib
        pop     psw
        ani     00fh
hexnib:
        adi     030h
        cpi     03ah
        jc      putc
        adi     7
        jmp     putc

mode:           db      0
optseen:        db      0
drive:          db      0
stage:          db      0

biotrk:         db      0
biosec:         db      0
bioptr:         dw      0

wrtrack:        db      0
sysleft:        db      0
systrks:        db      0
lastres:        db      0

firstv:         db      0
firstst:        db      0
finalst:        db      0
trycnt:         dw      0
cmdto:          dw      0
rspto:          dw      0
errbuf:         ds      8

msgtitle:       db 0dh,0ah,'PC-8001mkII CP/M FDFORMAT',0dh,0ah,'$'
msgusage:       db 'Usage: FDFORMAT [/S|/L] drive:',0dh,0ah
                db '       /S = bootable system disk, /L = low-level only',0dh,0ah,'$'
msgdrive_sel:   db 'Drive: $'
msgmode:        db '  Mode: $'
msgmode_data:   db 'CP/M data disk',0dh,0ah,'$'
msgmode_sys:    db 'bootable CP/M system disk',0dh,0ah,'$'
msgmode_low:    db 'low-level format only',0dh,0ah,'$'
msgwarn:        db 'ALL DATA ON THE TARGET DISK WILL BE LOST. CONTINUE? (Y/N) $'

msgsync:        db 'Synchronizing BIOS disk cache...',0dh,0ah,'$'
msgsave:        db 'Saving CP/M system tracks from A:...',0dh,0ah,'$'
msgbioserr:     db 'BIOS READ ERROR - FORMAT NOT STARTED',0dh,0ah,'$'
msgsystrkerr:   db 'INVALID BIOS DPB OFF / SYSTEM-TRACK SETTING',0dh,0ah,'$'

msginsert1:     db 'Insert disk to be formatted in drive $'
msginsert2:     db ':',0dh,0ah,'$'
msgpress:       db 'Press RETURN when ready. $'

msgformat:      db 'FORMATTING...$'
msgfmtok:       db 'LOW-LEVEL FORMAT SUCCESS',0dh,0ah,'$'
msgfmterr:      db 'FORMAT ERROR',0dh,0ah,'$'
msgfmttimeout:  db 'FORMAT STATUS TIMEOUT',0dh,0ah,'$'
msgcomm:        db 'FDD COMMUNICATION TIMEOUT AT STAGE $'

msgwritesys:    db 'Writing CP/M system tracks...',0dh,0ah,'$'
msgdir:         db 'Initializing CP/M directory...',0dh,0ah,'$'
msgwritefail:   db 'DISK WRITE ERROR AT TRACK $'

msgdone_data:   db 'CP/M DATA DISK CREATED SUCCESSFULLY',0dh,0ah,'$'
msgdone_sys:    db 'BOOTABLE CP/M SYSTEM DISK CREATED SUCCESSFULLY',0dh,0ah,'$'
msgdone_low:    db 'LOW-LEVEL FORMAT COMPLETED',0dh,0ah,'$'

msgrestore:     db 'Insert the original CP/M system disk in drive A:',0dh,0ah,'$'
msgrestore_err: db 'Insert the original CP/M system disk in drive A: before return to CCP.',0dh,0ah,'$'
msgabort:       db 'ABORTED',0dh,0ah,'$'

msgestatus:     db 'ERROR STATUS: $'
msgerrto:       db 'ERROR STATUS UNAVAILABLE (TIMEOUT)',0dh,0ah,'$'
msgfirst:       db 'FIRST=$'
msgfinal:       db ' FINAL=$'
msgtries:       db ' TRY=$'
msgcmdto:       db ' CMD_TO=$'
msgrspto:       db ' RSP_TO=$'

sysbuf:         ds      TRKLEN*MAX_SYS_TRKS

        end
