require "bit"

function dump_header()
  print(" PC   SP   OV  SKIP  A    B    C    D    E    F    G    H  ")
  print("---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ----")
end

function dump_state(cpu)
  print(string.format("%04x %04x %04x %s %04x %04x %04x %04x %04x %04x %04x %04x", 
	cpu.pc, cpu.sp, cpu.ov, tostring(cpu.skip), cpu.reg[0], cpu.reg[1], 
	cpu.reg[2], cpu.reg[3], cpu.reg[4], cpu.reg[5], cpu.reg[6], 
	cpu.reg[7]))
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
  elseif code >= 0x08 and code <= 0x0f then
    return cpu.mem[cpu.reg[bit.band(code, 7)]]
  elseif code >= 0x14 and code <= 0x17 then
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
    local val = cpu.pc
    cpu.pc = cpu.pc + 1
    return cpu.mem[val]
  elseif code == 0x1f then
    cpu.pc = cpu.pc + 1
    return cpu.pc
  else
    return code - 0x20
  end 
end

function step(cpu)
  local res = 0
  local op = cpu.mem[cpu.pc]
  cpu.pc = cpu.pc + 1
 
  local opcode = bit.band(op, 0x0F)
  local a = tonumber(bit.brshift(bit.band(op, 0x3F0), 4))
  local b = tonumber(bit.brshift(bit.band(op, 0xFC00), 10))
  
  local ma = get_op(cpu, a)
  local mb = get_op(cpu, b)

  if opcode == 0 then
    opcode = a
    if opcode == 0x01 then -- JSR
      ma = mb
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

  if cpu.skip == true then
    cpu.skip = false
    return
  end

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
    cpu.skip = not (ma == mb)  
  elseif opcode == 0x0D then -- IFN
    cpu.skip = not (ma ~= mb)
  elseif opcode == 0x0E then -- IFG
    cpu.skip = not (ma > mb) 
  elseif opcode == 0x0F then -- IFB
    cpu.skip = not (bit.band(ma, mb) ~= 0)
  else
    print("illegal op")
    os.exit(1)
  end

  if opcode == 0x02 and opcode <= 0x08 then
    cpu.ov = tonumber(bit.brshift(res, 16))
  end   
end

function load(cpu, file)
  local fp = io.input(file)
  if fp == nil then
    print("error reading file")
    os.exit(1)
  end 
end

function main()
  local dcpu = dcpu()

  --[[ load data
  if #arg >= 1 then
    local filename = arg[1]
  else
    local filename = "out.hex"
  end

  load(cpu, filename)
]]--


  dcpu.mem[0] = 0x7c01 
  dcpu.mem[1] = 0x0030 
  dcpu.mem[2] = 0x7de1
  dcpu.mem[3] = 0x1000
  dcpu.mem[4] = 0x0020

  dcpu.mem[5] = 0x7803
  dcpu.mem[6] = 0x1000

  dcpu.mem[7] = 0xa861

  dcpu.mem[8] = 0x7c01
  dcpu.mem[9] = 0x2000

  dcpu.mem[10] = 0x2161
  dcpu.mem[11] = 0x2000

  dcpu.mem[12] = 0x8463

  dcpu.mem[13] = 0x806d

  dcpu.mem[14] = 0x7dc1
  dcpu.mem[15] = 0x001a

  dcpu.mem[16] = 0x0000

  dump_header() 
  while true do
    dump_state(dcpu)
    step(dcpu)
  end

  return 0
end

main()
