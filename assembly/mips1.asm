addiu $t0, $0, 15
addiu $t1, $0, 0
addiu $t2, $0, 0
addiu $t3, $0, 1
.L1:
addu $t4, $t3, $t2
addu $t2, $t3, $0
addu $t3, $t4, $0
addiu $t1, $t1, 1
bne $t1, $t0, .L1
addu $2, $t2, $0
