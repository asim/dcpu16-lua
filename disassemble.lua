require "bit"

local opcode = {
  [0] = "XXX", [1] = "SET", [2] = "ADD", [3] = "SUB", [4] = "MUL", 
  [5] = "DIV", [6] = "MOD", [7] = "SHL", [8] = "SHR", [9] = "AND", 
  [10] = "BOR", [11] = "XOR", [12] = "IFE", [13] = "IFN", [14] = "IFG", 
  [15] = "IFB"
}

local regs = {
  [0] = "A", [1] = "B", [2] = "C", [3] = "X",
  [4] = "Y", [5] = "Z", [6] = "I", [7] = "J"
}

function dis_op(pc, n, mem)
  local s = ""
  if n < 0x08 then
   s = regs[bit.band(n, 7)]
  elseif n < 0x10 then
    s = string.format("[%s]", regs[bit.band(n, 7)])
  elseif n < 0x18 then
    s = string.format("[0x%04x+%s]", mem[pc],regs[bit.band(n, 7)])
    pc = pc + 1
  elseif n > 0x1f then
    s = n - 0x20
  else
    if n == 0x18 then s = "POP"
    elseif n == 0x19 then s = "PEEK"
    elseif n == 0x1A then s ="PUSH"
    elseif n == 0x1B then s = "SP"
    elseif n == 0x1C then s = "PC"
    elseif n == 0x1D then s = "O"
    elseif n == 0x1e then 
      s = string.format("[0x%04x]", mem[pc])
      pc = pc + 1
    elseif n == 0x1f then
      s = string.format("0x%04x", mem[pc])
      pc = pc + 1
    end
  end
  return pc, s
end

function disassemble(mem, pc)
  local s = ""
  local st = ""
  local n = mem[pc]
  pc = pc + 1

  local op = bit.band(n, 0xF)
  local a = bit.band(bit.brshift(n, 4), 0x3F)
  local b = bit.brshift(n, 10)
  if op > 0 then
    pc,st  = dis_op(pc, a, mem)
    s = s .. string.format("%s %s, ", opcode[op], st)
    pc,st = dis_op(pc, b, mem)
    s = s .. st
    return pc, s 
  end

  if a == 1 then
    pc,st = dis_op(pc, b, mem)
    s = s .. string.format("JSR %s", st)
    return pc, s
  end

  pc,st = dis_op(pc, b, mem)
  s = s .. string.format("UNK[%02x] %s", a, st)
  return pc, s 
end
