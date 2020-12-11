nop
or $t0, $0, $26
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
ori $t3, $0, 1
.L5: divu $s1, $t1
mfhi $t2
mflo $s1
add $t2, $t2, 0x30
sub $sp, $sp, 4
sw $t2, ($sp)
add $t3, $t3, 1
bne $s1, $0, .L5
sub $sp, $sp, 4
sw $t3, ($sp)
ori $27, $27, 0x2
ori $27, $27, 0x4
or $t0, $0, $26
sub $sp, $sp, 128
add $t2, $sp, 4
or $t3, $0, 0
.L6: lw $t1, ($t0)
sw $t1, ($t2)
add $t2, $t2, 4
add $t0, $t0, 4
add $t3, $t3, 1
bne $t1, 0, .L6
sw $t3, ($sp)
or $27, $27, 0x4
or $27, $27, 0x8
