# =============================================================
# main.s — VGA Video Player, NIOS II / DE2-115
# 320x240, RGB565, 24 FPS, 240 frames
# =============================================================
.equ WIDTH,                320
.equ HEIGHT,               240
.equ LOG2_BYTES_PER_ROW,   10       # log2(1024) — row = 1024 bytes
.equ LOG2_BYTES_PER_PIXEL, 1        # log2(2) — 2 bytes per pixel
.equ PIXBUF,               0x08000000
.equ TOTAL_FRAMES,         240

.global _start
_start:
    movia   sp, 0x800000
    movi    r12, TOTAL_FRAMES       # frame counter

    movia   r20, video_data_end
    subi    r20, r20, 4             # r20 points to the last word

    # r2 and r3 are constants — calculate once outside all loops
    movi    r2, LOG2_BYTES_PER_ROW
    movi    r3, LOG2_BYTES_PER_PIXEL

frame_loop:
    beq     r12, r0, done

    movi    r17, HEIGHT-1           # row: 239 -> 0

row_loop:
    movi    r16, WIDTH-2            # left column of the pair: 318, 316, ... 0

col_loop:
    ldw     r6, 0(r20)              # word = [left_p(31:16) | right_p(15:0)]
    subi    r20, r20, 4

    # Extract right pixel (col+1) — bits 15:0
    andi    r7, r6, 0xFFFF

    # Extract left pixel (col) — bits 31:16
    srli    r6, r6, 16

    # Write RIGHT pixel first at col+1
    # (we are moving from right to left, so col+1 is written first)
    addi    r4, r16, 1              # col + 1
    sll     r5, r17, r2             # row << 10
    sll     r4, r4, r3              # (col+1) << 1
    add     r5, r5, r4
    movia   r4, PIXBUF
    add     r5, r5, r4
    sthio   r7, 0(r5)

    # Write LEFT pixel at col
    sll     r5, r17, r2             # row << 10
    sll     r4, r16, r3             # col << 1
    add     r5, r5, r4
    movia   r4, PIXBUF
    add     r5, r5, r4
    sthio   r6, 0(r5)

    subi    r16, r16, 2             # next pair of columns
    bge     r16, r0, col_loop

    subi    r17, r17, 1
    bge     r17, r0, row_loop

    # Delay ~41ms at 50MHz
    movia   r14, 520833
delay_loop:
    subi    r14, r14, 1
    bne     r14, r0, delay_loop

    subi    r12, r12, 1
    br      frame_loop

done:
end_loop:
    br      end_loop