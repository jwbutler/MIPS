	.data
prompt1: .asciiz "Please enter the length of your array:"
prompt2: .asciiz "Please enter an integer:"
bye: .asciiz "Goodbye."
lnbrk: .asciiz "\n"
infinity: .word 0x7FFFFFFF
	.globl main
	.text
	
main:
	li $v0, 4				# Display the first prompt
	la $a0, prompt1
	syscall
	li $v0, 5				# Read an integer (array length)
	syscall
	ble $v0, $0, goodbye	# If length < 0, exit
	move $s2, $v0			# $s2 stores loop max
	move $a0, $v0
	addi $t4, $0, 4			# $t4 = 4 (constant)
	
	mul $a0, $a0, $t4
	li $v0, 9
	syscall					# Allocate array

	move $s0, $v0			# $s0 stores address of array
	li $t1, 0				# $t1 stores offset
	li $s1, 0				# $s1 stores i (loop counter)

loop:
	bge $s1, $s2, run
	
	li $v0, 4				# Display the second prompt
	la $a0, prompt2
	syscall
	
	li $v0, 5				# Read an integer
	syscall
	
	add $t0, $s0, $t1		# Calculate offset	
	sw $v0, 0($t0)			# Store the input
	addi $t1, $t1, 4		# Increment the memory pointer by 4
	addi $s1, $s1, 1		# and the counter by 1
	b loop
	
run:
	# Set up the main mergesort call.
	# Arrays are 1-indexed so start at 1.
	
	move $a0, $s0			# $a0 <= &A
	li $a1, 1
	move $a2, $s2
	jal mergesort
	
	# $a0 is already equal to &A, so we won't mess with it
	jal print
	
goodbye:
	la $a0, bye
	li $v0, 4
	syscall
	li $v0, 10
	syscall
	
merge:
	# $a0 => &A
	# $a1 => p
	# $a2 => q
	# $a3 => r
	
	addi $sp, $sp, -8
	sw $s0, 0($sp)			# Nothing is actually being stored in these, but it's good practice I guess
	sw $s1, 4($sp)
	
	sub $t0, $a2, $a1		# $t0 = n1 = q - p + 1
	addi $t0, $t0, 1
	
	sub $t1, $a3, $a2		# $t1 = n2 = r - q
	
	addi $t4, $0, 4			# t4 = 4
	addi $t2, $0, 1			# $t2 = i = 1
	
store_L:
	
	add $t5, $a1, $t2		# $t5 = p + i - 1
	addi $t5, $t5, -1
	
	mul $t5, $t5, $t4		# multiply $t5 by 4 for word offsets
	add $t5, $t5, $a0		# $t5 = &A[p+i-1]
	addi $t5, $t5, -4		# modify for 1-indexing
	
	lw $t6, 0($t5)
	addi $sp, $sp, -4		# Push A[p+i-1] onto the stack
	sw $t6, 0($sp)
	
	addi $t2, $t2, 1		# i++
	ble $t2, $t0, store_L	# if i <= n1, loop


	la $t6, infinity		# not part of the loop: add "infinity" as the next stack element
	lw $t6, 0($t6)
	addi $sp, $sp, -4
	sw $t6, 0($sp)
	
	addi $t2, $0, 1			# $t2 = j = 1

store_R:	
	add $t5, $a2, $t2		# $t5 = q + j
	mul $t5, $t5, $t4		# multiply $t5 by 4 for word offsets
	
	add $t5, $t5, $a0		# $t5 = &A[q + j]
	addi $t5, $t5, -4		# because 1-indexed
	
	lw $t6, 0($t5)			# $t6 = A[q + j]
	
	addi $sp, $sp, -4
	sw $t6, 0($sp)
	
	addi $t2, $t2, 1	
	ble $t2, $t1, store_R	# repeat while j <= n2
	
	la $t6, infinity		# not part of the loop: add "infinity" as the next stack element
	lw $t6, 0($t6)
	addi $sp, $sp, -4
	sw $t6, 0($sp)
	
	# now, execute the merge
	
	addi $t2, $0, 1			# $t2 = i = 1
	addi $t3, $0, 1			# $t3 = j = 1
	move $t5, $a1			# $t5 = k = p (for k = p to r)

mergeloop:
	add $t6, $t0, $t1		# $t6 = &L = $sp + 4(n1 + n2 + 1)
	addi $t6, $t6, 1		# for the infinities 
	mul $t6, $t6, $t4		# multiply for words
	add $t6, $t6, $sp

	addi $t7, $t1, 0		# $t7 = &R = $sp + 4(n2 + 0)
	mul $t7, $t7, $t4
	add $t7, $t7, $sp

	mul $t8, $t2, $t4		# $t8 = &L[i]
	add $t8, $t8, $t6
	addi $t8, -4			# because i and j start at 1

	mul $t9, $t3, $t4		# $t9 = &R[j]
	addi $t9, -4            # because i and j start at 1
	add $t9, $t9, $t7

	lw $t8, 0($t8)			# reusing registers here: moving contents of stored memory location
	lw $t9, 0($t9)			# into the register itself

	mul $s0, $t5, $t4		# $s0 = &A[k]
	add $s0, $s0, $a0
	addi $s0, $s0, -4		# offset for 1-indexing

	ble $t8, $t9, lessorequal
	bgt $t8, $t9, greaterthan

lessorequal:
	sw $t8, 0($s0)
	addi $t2, -1 			
	b mergeloopend

greaterthan:
	sw $t9, 0($s0)
	addi $t3, -1			
	b mergeloopend
	
mergeloopend:
	addi $t5, $t5, 1
	ble $t5, $a3, mergeloop	# if k <= r, repeat
	
	# clear the stack and return
	mul $t5, $t0, $t4		# $t5 = 4*n1
	add $sp, $sp, $t5		# pop L from stack
	mul $t5, $t1, $t4		# $t5 = 4*n2
	add $sp, $sp, $t5		# pop R from stack
	
	addi $sp, $sp, 8		# two infinities
	
	lw $s0, 0($sp)			# unused but good practice?
	lw $s1, 4($sp)			# unused but good practice?
	
	addi $sp, $sp, 8		# $s0, $s1
	
	jr $ra
	
mergesort:
	# $a0 => &A
	# $a1 => p
	# $a2 => r
	bge $a1, $a2, sortrtn
	li $t0, 2
	add $t1, $a1, $a2
	div $t1, $t1, $t0		# $t1 = q = (p+r)/2
	
	addi $sp, $sp, -16
	sw $a1, 0($sp)			# Store p	
	sw $t1, 4($sp)			# Store q
	sw $a2, 8($sp) 			# Store r
	sw $ra, 12($sp)			# Store return address
	
	move $a2, $t1			# Set up mergesort(A, p, q)
	
	jal mergesort			# Mergesort(A, p, q)
	lw $ra, 12($sp)			# Restore the return address pointer
	
	
							# Set up mergesort(A, q+1, r)
	lw $a1, 4($sp)
	addi $a1, $a1, 1
	lw $a2, 8($sp)
	
	jal mergesort			# Mergesort(A, q+1, r)
	
	lw $ra, 12($sp)			# Restore the return address pointer

	lw $a1, 0($sp)			# Set up merge(A, p, q, r)
	lw $a2, 4($sp)
	lw $a3, 8($sp)

	jal merge				# Merge(A, p, q,r)

	lw $ra, 12($sp)			# Restore the return address pointer

	lw $a1, 0($sp)
	lw $t1, 4($sp)
	lw $a2, 8($sp)

	addi $sp, $sp, 16		# clear stack

sortrtn:
	jr $ra

print:
	# $a0 => &A
	# $a2 => r

	move $t0, $0			# $t0 = offset
	move $t1, $a0
	addi $t4, $0, 4			# $t4 = 4

printloop:
	mul $t2, $t0, $t4
	add $t3, $t1, $t2
	lw $t5, 0($t3)

	li $v0, 1
	move $a0, $t5
	syscall

	li $v0, 4
	la $a0, lnbrk
	syscall

	addi $t0, $t0, 1
	blt $t0, $a2, printloop

	jr $ra