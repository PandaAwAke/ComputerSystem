ori $t1, $0, 0x7FFF0000
ori $t0, $0, 0x31
sw $t0, ($t1)
ori $t0, $0, 0x32
sw $t0, 4($t1)
ori $t0, $0, 0x33
sw $t0, 8($t1)
sw $0, 12($t1)
ori $t0, $0, 0x7FFF0000
ori $s0, $0, 0
ori $t3, $0, 10
.L1: lw $t1, ($t0)
beq $t1, $0, .L2
sub $t1, $t1, 0x30
multu $s0, $t3
mflo $s0
add $s0, $s0, $t1
add $t0, $t0, 4
j .L1
.L2: ori $s1, $0, 0
ori $t1, $0, 0
beq $t1, $s0, .L4
.L3: add $t1, $t1, 1
add $s1, $t1, $s1
bne $t1, $s0, .L3
.L4: ori $t1, $0, 10
sub $sp, $sp, 4
sw $0, ($sp)
.L5: divu $s1, $t1
mfhi $t2
mflo $s1
sub $sp, $sp, 4
sw $t2, ($sp)
bne $s1, $0, .L5
ori $13, $0, 0x7FFFEFFC
lw $2, -4($13)
lw $8, -8($13)
lw $9, -12($13)
lw $10, -16($13)
lw $11, -20($13)
lw $12, -24($13)
