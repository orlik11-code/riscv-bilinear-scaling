.data
input_path:	.asciz "input.bmp"
output_path:	.asciz "output.bmp"
new_width:	.asciz "Enter new file width: "
new_height:	.asciz "Enter new file height: "

.align 2
header_input:	.space 54
.text
.globl main

calc_pixel_value:

	add t2, t2, a7
	add t3, t3, a7
	add t4, t4, a7
	add t5, t5, a7

	# Q11 * (1-dx)*(1-dy)	
	lbu t6, (t2)
	mul t6, t6, a2
	srli t6, t6, 16
	mul t6, t6, a3
	srli t6, t6, 16
	mv s0, t6
	
	# Q21 * dx*(1-dy)
	lbu t6, (t3)
	mul t6, t6, a0
	srli t6, t6, 16
	mul t6, t6, a3
	srli t6, t6, 16
	add s0, s0, t6
	
	# Q12 * (1-dx)*dy
	lbu t6, (t4)
	mul t6, t6, a2
	srli t6, t6, 16
	mul t6, t6, a1
	srli t6, t6, 16
	add s0, s0, t6
	
	# Q22 * dx*dy
	lbu t6, (t5)
	mul t6, t6, a0
	srli t6, t6, 16
	mul t6, t6, a1
	srli t6, t6, 16
	add s0, s0, t6
	
	sub t2, t2, a7
	sub t3, t3, a7
	sub t4, t4, a7
	sub t5, t5, a7
	
	ret
	
offset:
	addi sp, sp, -8
	sw t2, 0(sp)
	sw t3, 4(sp)
	
	mv t2, s2
	addi t2, t2, -1
	sub t2, t2, a1
	
	mul t2, t2, s3
	
	li t3, 3
	mul t3, a0, t3
	
	add t2, t2, t3
	add a0, t2, s4
	
	lw t2, 0(sp)
	lw t3, 4(sp)
	addi sp, sp, 8
	
	ret

calc_old_integers:
	mul a5, a1, s7      # x_old_q16
	mul a6, a2, s8      # y_old_q16
	
	li t6, -1
	srli t6, t6, 16
	slli t6, t6, 16     # 0xFFFF0000
	
	and t2, a5, t6
	and t3, a6, t6
	
	srli t2, t2, 16     # x1
	srli t3, t3, 16     # y1
	
	addi t4, t2, 1
	addi t5, t3, 1
	
	addi t6, s1, -1
	blt t4, t6, skip_x
	mv t4, t6 # width edge_case
skip_x:

	addi t6, s2, -1
	blt t5, t6, skip_y
	mv t5, t6 # height edge_case
skip_y:

	mv a0, t2
	mv a1, t3
	mv a2, t4
	mv a3, t5
	ret

main:
	# file opening
	li a7, 1024
	la a0, input_path
	li a1, 0
	ecall
	mv s0, a0
	
	# reading header
	li a7, 63
	mv a0, s0
	la a1, header_input
	li a2, 54
	ecall
	
	la t0, header_input
	addi t0, t0, 16
	lw t1, (t0)
	lw t2, 4(t0)
	srli t1, t1, 16
	li t6, 0xFFFF
	and t2, t2, t6
	slli t2, t2, 16
	or s1, t1, t2 # width_input
	
	addi t0, t0, 4
	lw t1, (t0)
	lw t2, 4(t0)
	srli t1, t1, 16
	and t2, t2, t6
	slli t2, t2, 16
	or s2, t1, t2 # height_input
	
	li t0, 3
	mul t1, s1, t0
	mv t2, t1
	li t3, 4
	andi t2, t2, 3
	sub t3, t3, t2
	andi t3, t3, 3
	add s3, t1, t3 # row_size_input
	
	mul t0, s3, s2
	li a7, 9
	mv a0, t0
	ecall
	mv s4, a0 # buffer address
	
	# file -> buffer
	li a7, 63
	mv a0, s0
	mv a1, s4
	mv a2, t0
	ecall
	
	li a7, 57
	mv a0, s0
	ecall
	
collect_output_query:
	# new_width
	li a7, 4
	la a0, new_width
	ecall
	
	li a7, 5
	ecall
	mv s5, a0
	
	# new_height
	li a7, 4
	la a0, new_height
	ecall
	
	li a7, 5
	ecall
	mv s6, a0
	
calc_scales:
	# scale_x = ((old_width - 1) << 16) / (new_width - 1)
	addi t0, s1, -1
	slli t0, t0, 16
	addi t1, s5, -1
	div s7, t0, t1
	
	# scale_y = ((old_height - 1) << 16) / (new_height - 1)
	addi t0, s2, -1
	slli t0, t0, 16
	addi t1, s6, -1
	div s8, t0, t1
	
prepare_output_bmp:
	li t0, 3
	mul t1, s5, t0
	mv t2, t1
	li t3, 4
	andi t2, t2, 3
	sub t3, t3, t2
	andi t3, t3, 3
	add s9, t1, t3 # row_size_output 
	
	li a7, 9
	mul t0, s9, s6 # output buffer size
	mv a0, t0
	ecall
	mv s10, a0 # save bmp pointer
	
init_loop:
	li t0, 0
	li t1, 0

loop_y:
	beq t0, s6, end
	li t1, 0

loop_x:
	beq t1, s5, next_y
	
	mv a1, t1
	mv a2, t0
	jal ra, calc_old_integers
	
	mv t4, a0
	mv t5, a1
	mv t6, a2
	mv a7, a3
	
	# Q11
	mv a0, t4
	mv a1, t5
	jal ra, offset
	mv t2, a0
	
	# Q21
	mv a0, t6
	mv a1, t5
	jal ra, offset
	mv t3, a0
	
	# Q12
	mv a0, t4
	mv a1, a7
	jal ra, offset
	mv t4, a0
	
	# Q22
	mv a0, t6
	mv a1, a7
	jal ra, offset
	mv t5, a0
	
	# dx -> a0
	slli a0, a5, 16
	srli a0, a0, 16
	
	# dy -> a1
	slli a1, a6, 16
	srli a1, a1, 16
	
	# 2^16
	li t6, 65536
	
	# (1 - dx) -> a2
	sub a2, t6, a0
	
	# (1 - dy) -> a3
	sub a3, t6, a1
	
	li a7, 0
	jal ra, calc_pixel_value
	mv a5, s0
	
	addi a7, a7, 1
	jal ra, calc_pixel_value
	mv a6, s0
	
	addi a7, a7, 1
	jal ra, calc_pixel_value
	mv a7, s0
	
	mv t2, s6
	addi t2, t2, -1
	sub t2, t2, t0
	
	mul t2, t2, s9
	
	li t3, 3
	mul t3, t1, t3
	
	add t2, t2, t3
	add t2, t2, s10
	
	sb a5, (t2)
	sb a6, 1(t2)
	sb a7, 2(t2)
	
	addi t1, t1, 1
	j loop_x
	
next_y:
	addi t0, t0, 1
	j loop_y
	
end:

save_file:
	la t0, header_input
	    
	# file_size
	mul t1, s9, s6
	addi t1, t1, 54
	sh t1, 2(t0)
	srli t1, t1, 16
	sh t1, 4(t0)
	    
	# width
	sh s5, 18(t0)
	srli t1, s5, 16
	sh t1, 20(t0)
	    
	# height
	sh s6, 22(t0)
	srli t1, s6, 16
	sh t1, 24(t0)
	    
	# image size
	mul t1, s9, s6
	sh t1, 34(t0)
	srli t1, t1, 16
	sh t1, 36(t0)
	
	# open output file
	li a7, 1024
	la a0, output_path
	li a1, 1
	ecall
	mv s0, a0
	
	# header -> file
	li a7, 64
	mv a0, s0
	la a1, header_input
	li a2, 54
	ecall
	
	# buffer -> file
	li a7, 64
	mv a0, s0
	mv a1, s10
	mul a2, s9, s6
	ecall

	# close file
	li a7, 57
	mv a0, s0
	ecall
	
	li a7, 10
	ecall