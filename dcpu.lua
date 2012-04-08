require "bit"
require "disassemble"

function dump_header()
  print(" PC   SP   OV  SKIP  A    B    C    X    Y    Z    I    J   instruction")
  print("---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- -----------")
end

function dump_state(cpu)
  local _,st = disassemble(cpu.mem, cpu.pc)
  print(string.format("%04x %04x %04x %s %04x %04x %04x %04x %04x %04x %04x %04x %s", 
	cpu.pc, cpu.sp, cpu.ov, tostring(cpu.skip), cpu.reg[0], cpu.reg[1], 
	cpu.reg[2], cpu.reg[3], cpu.reg[4], cpu.reg[5], cpu.reg[6], 
	cpu.reg[7], st))
end

function dcpu()
  local ram_size = 0x10000
  local cpu = {}
  local registers = 8

  cpu.skip = false
  cpu.pc = 0
  cpu.sp = 0
  cpu.ov = 0
  cpu.mem = {}
  cpu.reg = {}
  cpu.st = {}

  for i=0,registers-1 do
    cpu.reg[i] = 0
  end

  for i=0,ram_size-1 do
    cpu.mem[i] = 0
  end

  return cpu
end

function get_op(cpu, code)
  if code < 0x08 then
    return cpu.reg[code]
  elseif code < 0x10 then
    return cpu.mem[cpu.reg[bit.band(code, 7)]]
  elseif code < 0x18 then
    local val = bit.band(cpu.reg[bit.band(code, 7)] + cpu.mem[cpu.pc], 0xFFFF)
    cpu.pc = cpu.pc + 1
    return cpu.mem[val]
  elseif code == 0x18 then
    local val = cpu.sp
    cpu.sp = cpu.sp + 1
    return cpu.mem[val]
  elseif code == 0x19 then
    return cpu.mem[cpu.sp]
  elseif code == 0x1a then
    cpu.sp = cpu.sp - 1
    return cpu.mem[cpu.sp]
  elseif code == 0x1b then
    return cpu.sp
  elseif code == 0x1c then
    return cpu.pc
  elseif code == 0x1d then
    return cpu.ov
  elseif code == 0x1e then
    local val = cpu.mem[cpu.pc]
    cpu.pc = cpu.pc + 1
    return cpu.mem[val]
  elseif code == 0x1f then
    local val = cpu.pc
    cpu.pc = cpu.pc + 1
    return cpu.mem[val]
  else
    return code - 0x20
  end 
end

function step(cpu)
  local dst, res, ma, mb, cop, op, opcode

  op = cpu.mem[cpu.pc]
  cpu.pc = cpu.pc + 1
 
  opcode = bit.band(op, 0x0F)
  cop = bit.band(bit.brshift(op, 4), 0x3F)

  if opcode == 0 then
    if cop == 0x01 then
      ma = get_op(cpu, bit.brshift(op, 10)) 

      if cpu.skip == true then
        cpu.skip = false
      else
        cpu.sp = cpu.sp - 1
        cpu.mem[cpu.sp] = cpu.pc
        cpu.pc = ma
      end
    
      return
    else
      print("illegal op")
      os.exit(1) 
    end
  end 

  dst = cop
  ma = get_op(cpu, dst)
  mb = get_op(cpu, bit.brshift(op, 10))

  if opcode == 0x01 then -- SET
    res = mb
  elseif opcode == 0x02 then -- ADD
    res = ma + mb
  elseif opcode == 0x03 then -- SUB
    res = ma - mb
  elseif opcode == 0x04 then -- MUL
    res = ma * mb
  elseif opcode == 0x05 then -- DIV
    if mb == 0 then res = 0 else res = ma / mb end 
  elseif opcode == 0x06 then -- MOD
    if mb == 0 then res = 0 else res = ma % mb end
  elseif opcode == 0x07 then -- SHL
    res = tonumber(bit.blshift(ma, mb))
  elseif opcode == 0x08 then -- SHR 
    res = tonumber(bit.brshift(ma,mb))
  elseif opcode == 0x09 then -- AND
    res = bit.band(ma, mb)
  elseif opcode == 0x0A then -- BOR
    res = bit.bor(ma, mb)
  elseif opcode == 0x0B then -- XOR
    res = bit.bxor(ma, mb)
  elseif opcode == 0x0C then -- IFE
    res = ma == mb  
  elseif opcode == 0x0D then -- IFN
    res = ma ~= mb
  elseif opcode == 0x0E then -- IFG
    res = ma > mb 
  elseif opcode == 0x0F then -- IFB
    res = bit.band(ma, mb) ~= 0
  else
    print("illegal op")
    os.exit(1)
  end
  
  if cpu.skip == true then
    cpu.skip = false
    return
  end
 
 if opcode == 0x02 and opcode <= 0x08 then
    cpu.ov = bit.brshift(res, 16)
  elseif opcode == 0x01 or
         opcode == 0x06 or
         opcode == 0x09 or
         opcode == 0x0A or
         opcode == 0x0B then

    if (dst < 0x1f) then cpu.reg[bit.band(dst, 7)] = res end
  elseif opcode >= 0x0C and opcode <= 0x0F then
    cpu.skip = res
  end   
end

function load(cpu, filename)
  local f = assert(io.open(filename, "rb"))
  local n = 0

  for line in f:lines() do
    if not line then break end
    bytes = tonumber(string.sub(line, 1, 4), 16)
    if bytes then
      cpu.mem[n] = bytes
      n = n + 1
    end
    
  end

  f:close()
end

function mem_set(cpu)
  cpu.mem[0] = 0x7c01 
  cpu.mem[1] = 0x0030 
  cpu.mem[2] = 0x7de1 
  cpu.mem[3] = 0x1000 
  cpu.mem[4] = 0x0020 
  cpu.mem[5] = 0x7803 
  cpu.mem[6] = 0x1000 
  cpu.mem[7] = 0xc00d 
  cpu.mem[8] = 0x7dc1 
  cpu.mem[9] = 0x001a 
  cpu.mem[10] = 0xa861 
  cpu.mem[11] = 0x7c01 
  cpu.mem[12] = 0x2000 
  cpu.mem[13] = 0x2161 
  cpu.mem[14] = 0x2000 
  cpu.mem[15] = 0x8463 
  cpu.mem[16] = 0x806d 
  cpu.mem[17] = 0x7dc1 
  cpu.mem[18] = 0x000d 
  cpu.mem[19] = 0x9031 
  cpu.mem[20] = 0x7c10 
  cpu.mem[21] = 0x0018 
  cpu.mem[22] = 0x7dc1 
  cpu.mem[23] = 0x001a 
  cpu.mem[24] = 0x9037 
  cpu.mem[25] = 0x61c1 
  cpu.mem[26] = 0x7dc1 
  cpu.mem[27] = 0xFFF0 
  cpu.mem[28] = 0x0000 
  cpu.mem[29] = 0x0000 
  cpu.mem[30] = 0x0000 
  cpu.mem[31] = 0x0000 
end

function main()
  local dcpu = dcpu()
  local filename = "out.hex"

  if #arg >= 1 then
    filename = arg[1]
  end

  -- load(dcpu, filename)

   mem_set(dcpu)

  dump_header() 
  while true do
    dump_state(dcpu)
    step(dcpu)
  end

  return 0
end

main()
