.data 
A:.space 240 
B:.space 240 
C:.space 240 
D:.space 240 
E:.space 240 
 
.text 
j main 
exc: 
nop   
j exc 
 
main: 
addi $2,$0,0 #a[i] 
addi $3,$0,1 #b[i] 
addi $4,$0,0 #c[i] 
addi $13,$0,0 #d[i] 
addi $5,$0,4 #counter 
addi $6,$0,0 #a[i-1] 
addi $7,$0,1 #b[i-1] 
addi $10,$0,0 #flag for i<20 || i<40   
addi $11,$0,240 #sum counts 
addi $14,$0,3 
addi $30,$0,0 

# 把 0 1 0 0 ($2,...,$13) 分别存入 A B C D
lui $27,0x0000 
addu $27,$27,$0 
sw $2,A($27)   
lui $27,0x0000 
addu $27,$27,$0 
sw $3,B($27)   
lui $27,0x0000 
addu $27,$27,$0 
sw $2,C($27)
lui $27,0x0000 
addu $27,$27,$0 
sw $3,D($27) 
 
# 循环
loop: 
## $5(4) 除以 4 存入 $12
srl $12,$5,2   
# $6 加 1
add $6,$6,$12 

# 把 $6 的内容存入 A[$5/4] 中
lui $27,0x0000 
addu $27,$27,$5 
sw $6,A($27) 
 
# $14 (3) 乘以 $5/4
mul $15,$14,$12 
# 把 $7 的内容加上 $14(3) * $5 / 4, 存入 B[$5/4]
add $7,$7,$15   
lui $27,0x0000 
addu $27,$27,$5 
sw $7,B($27) 
 
# $5 是否小于 80? 记入 $10
slti $10,$5,80 
# 若是, 跳转
bne $10,1,c1   

# 把 $6 的内容存入 C[$5/4] 中
lui $27,0x0000 
addu $27,$27,$5 
sw $6,C($0)   

# 把 $7 的内容存入 D[$5/4] 中
lui $27,0x0000 
addu $27,$27,$5 
sw $7,D($0) 
addi $15,$6,0 
addi $16,$7,0 
j endc 


c1: 
slti $10,$5,160 
addi $27,$0,1 
bne $10,$27,c2 
add $15,$6,$7   
lui $27,0x0000 
addu $27,$27,$5 
sw $15,C($27) 
 
mul $16, $15,$6   
lui $27,0x0000 
addu $27,$27,$5 
sw $16,D($27) 
 
j endc 
c2: 
mul $15,$6,$7   
lui $27,0x0000 
addu $27,$27,$5 
sw $15,C($27) 
 
mul $16,$15,$7   
lui $27,0x0000 
addu $27,$27,$5 
sw $16,D($27) 
 
endc: 
add $28,$15,$16   
lui $27,0x0000 
addu $27,$27,$5 
sw $28,E($27) 
addi $5,$5,4 
bne $5,$11,loop 
break 
