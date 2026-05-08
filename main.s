# =============================================================
# main.s — VGA Video Player, NIOS II / DE2-115
# 320x240, RGB565, 24 FPS, 240 frames
# =============================================================

.equ WIDTH,               320
.equ HEIGHT,              240
.equ LOG2_BYTES_PER_ROW,  10        # log2(1024) — row = 1024 bytes
.equ LOG2_BYTES_PER_PIXEL, 1        # log2(2) — 2 bytes per pixel
.equ PIXBUF,              0x08000000
.equ TOTAL_FRAMES,        240
.equ WORDS_PER_FRAME,     76800     # 320*240 words (one pixel per word)

.global _start
_start:
    movia    sp, 0x800000           # stack pointer

    movi     r12, TOTAL_FRAMES      # frame counter

    # Initial index: points to the LAST word of the last frame
    # Total words = 240 frames * 76800 = 18,432,000
    # Index in bytes = 18,432,000 * 4 - 4 = 73,727,996
    # But we start from frame 0 backwards, so:
    # At the start of frame 0 in the file = word 0
    movia    r20, video_data_end
    subi     r20, r20, 4            # r20 = pointer to the last word

frame_loop:
    beq      r12, r0, done

    # Draw a frame pixel by pixel using coordinates
    movi     r17, HEIGHT-1          # row = 239 to 0

row_loop:
    movi     r16, WIDTH-1           # column = 319 to 0

col_loop:
    # Read pixel from data
    ldw      r6, 0(r20)
    subi     r20, r20, 4            # move back to the previous word

    # Calculate address in the pixel buffer
    # addr = PIXBUF + (row << 10) + (col << 1)
    movi     r2, LOG2_BYTES_PER_ROW
    movi     r3, LOG2_BYTES_PER_PIXEL
    sll      r5, r17, r2            # row << 10
    sll      r4, r16, r3            # col << 1
    add      r5, r5, r4
    movia    r4, PIXBUF
    add      r5, r5, r4
    sthio    r6, 0(r5)              # write 16-bit pixel

    subi     r16, r16, 1
    bge      r16, r0, col_loop

    subi     r17, r17, 1
    bge      r17, r0, row_loop

    # Delay ~41ms (adjust if the video is too fast or slow)
    movia    r14, 1041666
delay_loop:
    subi     r14, r14, 1
    bne      r14, r0, delay_loop

    subi     r12, r12, 1
    br       frame_loop

done:
end_loop:
    br       end_loop
