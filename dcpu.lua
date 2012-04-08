require "bit"
require "disassemble"

DEBUG = true


function debug(msg)
  if DEBUG then 
    print(msg)
  end
end

function dump_header()
  print(" PC   SP   OV  SKIP  A    B    C    X    Y    Z    I    J   instruction")
  print("---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- -----------")
end

function dump_state(cpu)
  local _,st = disassemble(cpu.mem, cpu.pc)
  local sp = string.sub(string.format("%04x", cpu.sp), 1, 4)
  print(string.format("%04x %s %04x %s %04x %04x %04x %04x %04x %04x %04x %04x %s", 
	cpu.pc, sp, cpu.ov, tostring(cpu.skip), cpu.reg[0], cpu.reg[1], 
	cpu.reg[2], cpu.reg[3], cpu.reg[4], cpu.reg[5], cpu.reg[6], 
	cpu.reg[7], st))
end

function dcpu()
  local ram_size = 0x10000
  local literals = 32
  local cpu = {}
  local registers = 8

  cpu.skip = false
  cpu.pc = 0
  cpu.sp = 0
  cpu.ov = 0
  cpu.mem = {}
  cpu.reg = {}
  cpu.lit = {}

  for i=0,registers-1 do
    cpu.reg[i] = 0
  end

  for i=0,ram_size-1 do
    cpu.mem[i] = 0
  end

  for i=0,literals-1 do
    cpu.lit[i] = i
  end

  return cpu
end

function get_op(cpu, op)
  local reg = "reg"
  local mem = "mem"
  local lit = "lit"
  local ov = "ov"
  local pc = "pc"
  local sp = "sp"

  debug(string.format("pc: %s op: %s", cpu.pc, op))

  if op < 0x08 then
    return reg, op
  elseif op < 0x10 then
    return mem, cpu.reg[bit.band(op, 7)]
  elseif op < 0x18 then
    local val = bit.band(cpu.reg[bit.band(op, 7)] + cpu.mem[cpu.pc], 0xFFFF)
    cpu.pc = cpu.pc + 1
    return mem, val
  elseif op == 0x18 then
    local val = cpu.sp
    cpu.sp = cpu.sp + 1
    return mem, val
  elseif op == 0x19 then
    return mem, cpu.sp
  elseif op == 0x1A then
    cpu.sp = cpu.sp - 1
    return mem, cpu.sp
  elseif op == 0x1B then
    return sp, cpu.sp
  elseif op == 0x1C then
    return pc, cpu.pc
  elseif op == 0x1D then
    return ov, cpu.ov
  elseif op == 0x1E then
    debug(string.format("0x1e %s", cpu.pc))

    local val = cpu.mem[cpu.pc]
    cpu.pc = cpu.pc + 1
    return mem, val
  elseif op == 0x1F then
    debug(string.format("0x1f %s", cpu.pc))

    local val = cpu.pc
    cpu.pc = cpu.pc + 1
    return mem, val
  else
    return lit, (op - 0x20) % 32
  end 
end

function read(cpu, op, val)
  if op == "mem" then
    return cpu.mem[val]
  elseif op == "reg" then
    return cpu.reg[val]
  elseif op == "pc" then
    return cpu.pc
  elseif op == "sp" then
    return cpu.sp
  elseif op == "ov" then
    return cpu.ov
  elseif op == "lit" then
    return val
  end
end

function write(cpu, op, val, value)
  if op == "mem" then
    cpu.mem[val] = value
  elseif op == "reg" then
    cpu.reg[val] = value
  elseif op == "pc" then
    debug(string.format("write pc: %s", value))
    cpu.pc = value
  end
end

function step(cpu)
  local a, b, dst, loc, res, ma, mb, cop, op, opcode

  op = cpu.mem[cpu.pc]
  cpu.pc = cpu.pc + 1
 
  opcode = bit.band(op, 0x0F)
  cop = bit.band(bit.brshift(op, 4), 0x3F)

  if opcode == 0 then
    if cop == 0x01 then
      aloc,ma = get_op(cpu, bit.brshift(op, 10)) 
      ma = read(cpu, aloc, ma)
      
      if cpu.skip == true then
        cpu.skip = false
      else
        cpu.sp = cpu.sp - 1
        cpu.mem[cpu.sp] = cpu.pc
        cpu.pc = ma
        debug(string.format("cpu.sp %04x cpu.pc %s ma %s", cpu.sp, cpu.pc, ma))
      end
    
      return
    else
      print("illegal op")
      os.exit(1) 
    end
  end 

  res = 0
  dst = cop
  aloc, a = get_op(cpu, dst)
  bloc, b = get_op(cpu, bit.brshift(op, 10))
  
  ma = read(cpu, aloc, a) 
  mb = read(cpu, bloc, b)

  debug(string.format("ma %s mb %s",ma, mb))

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
    res = bit.blshift(ma, mb)
  elseif opcode == 0x08 then -- SHR 
    res = bit.brshift(ma, mb)
  elseif opcode == 0x09 then -- AND
    res = bit.band(ma, mb)
  elseif opcode == 0x0A then -- BOR
    res = bit.bor(ma, mb)
  elseif opcode == 0x0B then -- XOR
    res = bit.bxor(ma, mb)
  elseif opcode == 0x0C then -- IFE
    res = ma ~= mb  
  elseif opcode == 0x0D then -- IFN
    res = ma == mb
  elseif opcode == 0x0E then -- IFG
    res = ma <= mb 
  elseif opcode == 0x0F then -- IFB
    res = bit.band(ma, mb) == 0
  else
    print("illegal op")
    os.exit(1)
  end
  
  if cpu.skip == true then
    cpu.skip = false
    return
  end
 
  if opcode >= 0x0C and opcode <= 0x0F then
    debug(string.format("res skip %s", tostring(res)))
    cpu.skip = res
  else
    debug(string.format("setting cpu[%s][%s] = %s", aloc, a, res))
    write(cpu, aloc, a, res)
    cpu.ov = bit.band(bit.brshift(res, 16), 0xFFFF)
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

  load(dcpu, filename)

  -- mem_set(dcpu)

  dump_header() 
  while true do
    dump_state(dcpu)
    step(dcpu)
  end

  return 0
end

main()
