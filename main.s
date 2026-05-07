# =============================================================
# main.s — VGA Video Player for NIOS II / DE2-115
# Resolution: 320x240, RGB565, 24 FPS, 10 seconds (240 frames)
# =============================================================
# Relevant memory map (typical DE2-115 with QSYS):
#   SDRAM base:            0x00000000  (where our code+data lives)
#   VGA Pixel Buffer ctrl: 0xFF203020  (control register)
#   VGA Pixel Buffer 0:    0xC8000000  (default back buffer)
#   Timer base:            0xFF202000
# =============================================================

.equ PIXEL_BUF_CTRL,  0xFF203020   # VGA Controller address
.equ TIMER_BASE,      0xFF202000   # Interval Timer
# At 24 FPS, one frame lasts: 1/24 sec ≈ 41.67 ms
# The DE2-115 timer runs at 100 MHz (period = 10 ns)
# Counts for 41.67 ms = 41,666,667 ≈ 0x027FFFFF... we use 0x027A2780
.equ FRAME_DELAY,     0x027A2780   # ~41.6ms at 100MHz
.equ FRAME_W,          320
.equ FRAME_H,          240
.equ PIXELS_PER_FRAME, 76800       # 320*240
.equ WORDS_PER_FRAME,  38400       # 76800/2 (2 pixels per 32-bit word)
.equ TOTAL_FRAMES,    240

.section .text
.global _start

_start:
    # ---------------------------------------------------------
    # 1. Initialize stack pointer
    # ---------------------------------------------------------
    movia   sp, 0x007FFFFC     # Top of SDRAM (adjust if your map changes)

    # ---------------------------------------------------------
    # 2. Get pixel buffer address (back buffer)
    # ---------------------------------------------------------
    movia   r8, PIXEL_BUF_CTRL
    ldw     r9, 4(r8)          # ctrl register 1 = back buffer address
    # r9 = pixel buffer base address (e.g., 0xC8000000)

    # ---------------------------------------------------------
    # 3. Load pointer to the start of video data
    # ---------------------------------------------------------
    movia   r10, video_data_start   # r10 = pointer to current frame

    # ---------------------------------------------------------
    # 4. Load timer address
    # ---------------------------------------------------------
    movia   r11, TIMER_BASE

    # ---------------------------------------------------------
    # 5. Frame counter
    # ---------------------------------------------------------
    movi    r12, TOTAL_FRAMES       # r12 = 240 (remaining frames)

frame_loop:
    # Are all frames finished?
    beq     r12, r0, done

    # ---------------------------------------------------------
    # 6. Copy a frame to the pixel buffer
    #    Each frame consists of WORDS_PER_FRAME 32-bit words
    #    Copy word by word from r10 to r9
    # ---------------------------------------------------------
    mov     r4, r9              # r4 = destination (pixel buffer)
    mov     r5, r10             # r5 = source (frame data)
    movi    r6, WORDS_PER_FRAME # r6 = word counter

copy_loop:
    beq     r6, r0, copy_done
    ldw     r7, 0(r5)           # read word from frame
    stw     r7, 0(r4)           # write to pixel buffer
    addi    r5, r5, 4           # advance source
    addi    r4, r4, 4           # advance destination
    subi    r6, r6, 1
    br      copy_loop

copy_done:
    # Update r10 to the next frame
    # Each frame occupies WORDS_PER_FRAME * 4 bytes
    movi    r13, WORDS_PER_FRAME
    slli    r13, r13, 2         # r13 = WORDS_PER_FRAME * 4 = 153600
    add     r10, r10, r13       # advance to next frame

    # ---------------------------------------------------------
    # 7. Swap buffer (show what we just wrote)
    # ---------------------------------------------------------
    movia   r8, PIXEL_BUF_CTRL
    movi    r14, 1
    stw     r14, 0(r8)          # write 1 to register 0 = request swap

wait_swap:
    ldw     r15, 0(r8)          # read register 0
    andi    r15, r15, 1         # bit 0 = swap pending
    bne     r15, r0, wait_swap  # wait until swap occurs

    # After swap, the new back buffer might have changed
    ldw     r9, 4(r8)           # re-read back buffer address

    # ---------------------------------------------------------
    # 8. Wait for one frame time (~41.6 ms) using the timer
    # ---------------------------------------------------------
    # Load value into timer and start it
    movia   r14, FRAME_DELAY
    stw     r14, 8(r11)         # Timer period low
    movi    r14, 0
    stw     r14, 12(r11)        # Timer period high
    movi    r14, 0b0110         # START=1, CONT=0 (one-shot), ITO=0
    stw     r14, 4(r11)         # Timer control register

wait_timer:
    ldw     r15, 0(r11)         # read timer status
    andi    r15, r15, 1         # bit 0 = TO (timeout)
    beq     r15, r0, wait_timer # wait until timeout
    # Clear TO flag by writing 0
    stw     r0, 0(r11)

    # ---------------------------------------------------------
    # 9. Decrement counter and repeat
    # ---------------------------------------------------------
    subi    r12, r12, 1
    br      frame_loop

done:
    # Video finished — black screen or loop
    # For infinite loop, uncomment the next two lines:
    # movia   r10, video_data_start
    # movi    r12, TOTAL_FRAMES
    # br      frame_loop

    # To stay halted:
end_loop:
    br      end_loop

# =============================================================
# Include video data (generated by Colab)
# =============================================================
.include "video_data.s"