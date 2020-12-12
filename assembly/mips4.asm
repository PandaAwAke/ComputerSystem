or $27, $27, 0x1
or $t0, $0, $26
sub $sp, $sp, 128
add $t2, $sp, 4
or $t3, $0, 0
.L1: lw $t1, ($t0)
sw $t1, ($t2)
add $t2, $t2, 4
add $t0, $t0, 4
add $t3, $t3, 1
bne $t1, 0, .L1
sw $t3, ($sp)
ori $27, $27, 0x2
ori $27, $27, 0x4
or $t0, $0, $26
sub $sp, $sp, 128
add $t2, $sp, 4
or $t3, $0, 0
.L2: lw $t1, ($t0)
sw $t1, ($t2)
add $t2, $t2, 4
add $t0, $t0, 4
add $t3, $t3, 1
bne $t1, 0, .L2
sw $t3, ($sp)
or $27, $27, 0x2
or $27, $27, 0x8
