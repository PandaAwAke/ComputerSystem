import os

fr = open('project/init_files/t2', 'rb')
fw = open('project/init_files/instr_ram.mif', 'w')
depth = 1024
width = 32
fw.write('WIDTH = %d;\n' % width)
fw.write('DEPTH = %d;\n\n' % depth)
fw.write('ADDRESS_RADIX=HEX;\n')
fw.write('DATA_RADIX=HEX;\n\n')
fw.write('CONTENT BEGIN\n')
s = 0
for i in range(os.path.getsize('project/init_files/t2')):
    tmp = fr.read(4)
    num = int.from_bytes(tmp, 'little')
    fw.write('   {:0>3X} : {:0>8X} ;\n'.format(s, num))
    s += 1
while s < depth:
    fw.write('   {:0>3X} : {:0>8X} ;\n'.format(s, 0))
    s += 1
fw.write('END;')
