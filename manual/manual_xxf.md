# XXF组内对接操作手册

KEY[0]的作用是在程序死循环的时候或者单步执行等待时按一下就直接退出程序

KEY[3]的作用是单步执行时按一下就执行下一步

寄存器说明

| 编号 | 名称  |                     约定                     |
| :--: | :---: | :------------------------------------------: |
|  0   | zero  |             初始为0，不应该修改              |
|  26  |  k0   | 初始为0x7fff0000，指示输入内容放置的起始地址 |
|  27  |  k1   |          control register，初始为0           |
|  29  |  sp   |           栈指针，初始为0x7fffeffc           |
|  31  |  ra   |             返回地址，jal指令用              |
|      | lo,hi |                 乘除法的结果                 |
|      |  pc   |          指令计数器，初始为0x400000          |

其他0-31中没有说明的随便用，可以根据[mips寄存器](https://blog.csdn.net/shliushliu/article/details/103336056)的建议使用

control register的说明

| 位数 |  名称  |                        含义                        |
| :--: | :----: | :------------------------------------------------: |
|  0   | debug  | 为1进入调试模式，使用按钮，每条指令输出PC和指令码  |
|  1   | output |        为1表示需要输出内容，cpu输出完会置0         |
|  2   | input  |        为1表示需要输入内容，cpu输入完会置0         |
|  3   |  end   |         为1表示程序执行结束，cpu之后会置0          |
|  4   | audio  | 为1表示开启键盘音效，开机时为0，之后完全由程序控制 |

指令条数最多为1024条

实现的指令

add, addu, sub, subu, slt, sltu, and, or, xor, nor, sll, srl, sra, sllv, srlv, srav, jr, addi, addiu, slti, sltiu, andi, ori, xori, lui, lw, sw, beq, bne, j, jal, div, divu, mult, multu, mflo, mfhi

| 指令 |                          |
| :--: | :----------------------: |
| 乘法 | 64位的结果放在{hi, lo}中 |
| 除法 |   余数在hi中，商在lo中   |

这与能写什么汇编指令不同，某些格式的div就会展开出mfhi，sub根据操作数可能会编译出sub或subi

内存最多放16K个32bit，这就是说内存地址的低2位应始终为0，只能放32位的数

![image-20201211144912098](D:\academic\Experiments in Digital Logical Circuits\ComputerSystem\manual\image-20201211144912098.png)

内存和指令都可以扩充，目前使用量约为

![image-20201211124535950](D:\academic\Experiments in Digital Logical Circuits\ComputerSystem\manual\image-20201211124535950.png)

做了一个简单的地址映射，数据段物理地址为虚拟地址的低16位，代码段物理地址为虚拟地址的低12位

数据和代码放在两个不同的区域，不能相互访问

初始时会自动先读入，读入的字符会放在从k0(0x0000)开始的内存中，每32bit放一个字符，0表示结束

之后若请求读入需先设置k0，不改也可以。程序运行时应该可以随便用（不建议），仅在请求读入时正确设置。

读入都只能读一行，以0结尾。

程序需要输出时需依次把需要输出的字符放在sp开始的内存中，每32bit放一个字符，0表示**换行**（也就是说依次从最后一位（结束符0）到第一位压栈）。最后把字符串长度（包含末尾的0，即最少为1）压在(sp)处。

一次最多能输入输出多少个字符要问mss

zss的任务：生成`instr_ram.mif`，0x400000处的指令放在0处，以此类推。在tool中有一个简单的`bin2mif.py`示例，assembly中有范例汇编文件（只有`mips3.asm`是可以放在我们的机器上的，其他的是编写的参考）

若有必要，生成`main_memory.mif`，但只有第一次有效，再次从头运行程序的时候没用

空指令nop为全0

![image-20201211152614555](D:\academic\Experiments in Digital Logical Circuits\ComputerSystem\manual\image-20201211152614555.png)

![image-20201211152629727](D:\academic\Experiments in Digital Logical Circuits\ComputerSystem\manual\image-20201211152629727.png)

注意

- 没有adc，sbb指令
- 有符号指令和无符号指令之间的唯一区别是有符号指令可以产生溢出异常，不溢出才装入，而无符号指令则不会，会装入溢出结果。但addi和addiu资料间有歧义，我实现的addiu做的是零扩展

- div，divu和mul，mulu两组实现上没有区别，建议用u
- 有imm的，addi，lw，sw，beq，bne，slt做了符号扩展，逻辑指令、sltiu、addiu做了零扩展
- 我说的全都是我可以执行的指令，而不是可编写的指令。比如subi，汇编器会自动拆分成含addi的几条指令

我的一点设想，最终咋整全看zss的

- shell就是shell，不存在什么文本模式，一开始程序读到的一定是命令，不然就输出invalid command等。但是应该可以比如输入vim，就进入不断请求输入的循环，直到输入q，之类的
- 假设`accum 123`就输出1到123的累加结果，那么`gdb accum 123`进入单步执行模式，最后输出结果，对于程序的区别就是进入子程序段前要设置control register的debug位，结束后恢复之（也许不用恢复，目前的版本默认进入调试模式，正式版本不会默认进入并且会在每次程序初始化时恢复control register的debug位）
- 假设`audio on`打开键盘音效，`audio off`则关闭。除非检测到这两个命令，否则control register的audio位不会自动恢复
- 最终生成的文件中最前面一段是指令解析，之后跳到各个子程序段，每个子程序段结束都得设置control register的end位表明程序结束
- 每次开始运行（即第一次或每次设置control register的end位之后）都是从第一条指令开始

