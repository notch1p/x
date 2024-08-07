// Copyright 2024 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// An MD5 message-digest algorithm implementation based on
// [RFC1321]       https://www.ietf.org/rfc/rfc1321.txt
// [Ron Rivest]    https://people.csail.mit.edu/rivest/Md5.c
// [md5-0.7.0]     https://docs.rs/md5/0.7.0/src/md5/lib.rs.html 
struct MD5Context {
  state : FixedArray[UInt] // state 'a' 'b' 'c' 'd'
  count : FixedArray[UInt]
  buffer : Bytes
}

let padding : Bytes = Bytes::make(64, b'\x00')

/// update the state of given context from new `data` 
pub fn MD5Context::update(self : MD5Context, data : Bytes) -> Unit {
  md5_update(self, data)
}

/// an alias of `MD5Context::compute()`
pub fn MD5Context::finalize(self : MD5Context) -> Bytes {
  self.compute()
}

/// Instantiate a MD5 context
pub fn MD5Context::make() -> MD5Context {
  padding[0] = b'\x80'
  {
    state: [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476],
    count: [0, 0],
    buffer: Bytes::make(64, b'\x00'),
  }
}

/// compute MD5 digest from given context
pub fn MD5Context::compute(self : MD5Context) -> Bytes {
  let input = FixedArray::make(16, 0U)
  let idx = (self.count[0].lsr(3) & 0x3f).to_int()
  input[14] = self.count[0]
  input[15] = self.count[1]
  let bytes_slice = if idx < 56 {
    let bytes_slice = Bytes::make(56 - idx + 1, b'\x00')
    bytes_slice.blit(0, padding, 0, 56 - idx + 1)
    bytes_slice
  } else {
    let bytes_slice = Bytes::make(120 - idx + 1, b'\x00')
    bytes_slice.blit(0, padding, 0, 120 - idx + 1)
    bytes_slice
  }
  md5_update(self, bytes_slice)
  let mut j = 0
  for i = 0; i < 14; i = i + 1 {
    input[i] = u8_to_u32le(self.buffer, i=j)
    j += 4
  }
  md5_transform(self.state, input)
  let digest = Bytes::make(16, b'\x00')
  let mut j = 0
  // u32 to u8
  for i = 0; i < 4; i = i + 1 {
    digest[j] = (self.state[i] & 0xff).to_int().to_byte()
    digest[j + 1] = (self.state[i].lsr(8) & 0xff).to_int().to_byte()
    digest[j + 2] = (self.state[i].lsr(16) & 0xff).to_int().to_byte()
    digest[j + 3] = (self.state[i].lsr(24) & 0xff).to_int().to_byte()
    j += 4
  }
  digest
}

// no macros, nor inline. basic md5 functions
// four auxiliary functions
//          F(X,Y,Z) = XY v not(X) Z
//          G(X,Y,Z) = XZ v Y not(Z)
//          H(X,Y,Z) = X xor Y xor Z
//          I(X,Y,Z) = Y xor (X v not(Z))
fn MD5Context::f(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) | (x.lnot() & z)
}

fn MD5Context::g(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & z) | (y & z.lnot())
}

fn MD5Context::h(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ y ^ z
}

fn MD5Context::i(x : UInt, y : UInt, z : UInt) -> UInt {
  y ^ (x | z.lnot())
}

fn md5_update(ctx : MD5Context, data : Bytes) -> Unit {
  let input = FixedArray::make(16, 0U)
  let mut idx = (ctx.count[0].lsr(3) & 0x3f).to_int()
  let length = data.length()
  let mod_length = length.to_uint().lsl(3)
  ctx.count[0] += mod_length
  if ctx.count[0] < mod_length {
    ctx.count[1] += 1
  }
  ctx.count[1] += length.to_uint().lsr(29)
  for i = 0; i < length; i = i + 1 {
    ctx.buffer[idx] = data[i]
    idx += 1
    if idx == 0x40 {
      let mut j = 0
      for k = 0; k < 16; k = k + 1 {
        input[k] = u8_to_u32le(ctx.buffer, i=j)
        j += 4
      }
      md5_transform(ctx.state, input)
      idx = 0
    }
  }
}

fn md5_transform(state : FixedArray[UInt], input : FixedArray[UInt]) -> Unit {
  let a = Ref::new(state[0])
  let b = Ref::new(state[1])
  let c = Ref::new(state[2])
  let d = Ref::new(state[3])
  fn t(
    op : (UInt, UInt, UInt) -> UInt,
    state_a : Ref[UInt],
    state_b : Ref[UInt],
    state_c : Ref[UInt],
    state_d : Ref[UInt],
    k : Int,
    s : Int, // calculate w/ floor(2^32 * |sin(i + 1)|) for i in 0..63
    ac : UInt
  ) -> Unit {
    state_a.val = state_b.val + urotate_left(
        state_a.val + op(state_b.val, state_c.val, state_d.val) + input[k] + ac,
        s,
      )
  }

  // Round 1
  // s[ 0..15] := { 7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22 }
  t(f, a, b, c, d, 0, 7, 0xd76aa478)
  t(f, d, a, b, c, 1, 12, 0xe8c7b756)
  t(f, c, d, a, b, 2, 17, 0x242070db)
  t(f, b, c, d, a, 3, 22, 0xc1bdceee)
  t(f, a, b, c, d, 4, 7, 0xf57c0faf)
  t(f, d, a, b, c, 5, 12, 0x4787c62a)
  t(f, c, d, a, b, 6, 17, 0xa8304613)
  t(f, b, c, d, a, 7, 22, 0xfd469501)
  t(f, a, b, c, d, 8, 7, 0x698098d8)
  t(f, d, a, b, c, 9, 12, 0x8b44f7af)
  t(f, c, d, a, b, 10, 17, 0xffff5bb1)
  t(f, b, c, d, a, 11, 22, 0x895cd7be)
  t(f, a, b, c, d, 12, 7, 0x6b901122)
  t(f, d, a, b, c, 13, 12, 0xfd987193)
  t(f, c, d, a, b, 14, 17, 0xa679438e)
  t(f, b, c, d, a, 15, 22, 0x49b40821)

  // Round 2
  // s[16..31] := { 5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20 }
  t(g, a, b, c, d, 1, 5, 0xf61e2562)
  t(g, d, a, b, c, 6, 9, 0xc040b340)
  t(g, c, d, a, b, 11, 14, 0x265e5a51)
  t(g, b, c, d, a, 0, 20, 0xe9b6c7aa)
  t(g, a, b, c, d, 5, 5, 0xd62f105d)
  t(g, d, a, b, c, 10, 9, 0x02441453)
  t(g, c, d, a, b, 15, 14, 0xd8a1e681)
  t(g, b, c, d, a, 4, 20, 0xe7d3fbc8)
  t(g, a, b, c, d, 9, 5, 0x21e1cde6)
  t(g, d, a, b, c, 14, 9, 0xc33707d6)
  t(g, c, d, a, b, 3, 14, 0xf4d50d87)
  t(g, b, c, d, a, 8, 20, 0x455a14ed)
  t(g, a, b, c, d, 13, 5, 0xa9e3e905)
  t(g, d, a, b, c, 2, 9, 0xfcefa3f8)
  t(g, c, d, a, b, 7, 14, 0x676f02d9)
  t(g, b, c, d, a, 12, 20, 0x8d2a4c8a)

  // Round 3
  // s[32..47] := { 4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23 }
  t(h, a, b, c, d, 5, 4, 0xfffa3942)
  t(h, d, a, b, c, 8, 11, 0x8771f681)
  t(h, c, d, a, b, 11, 16, 0x6d9d6122)
  t(h, b, c, d, a, 14, 23, 0xfde5380c)
  t(h, a, b, c, d, 1, 4, 0xa4beea44)
  t(h, d, a, b, c, 4, 11, 0x4bdecfa9)
  t(h, c, d, a, b, 7, 16, 0xf6bb4b60)
  t(h, b, c, d, a, 10, 23, 0xbebfbc70)
  t(h, a, b, c, d, 13, 4, 0x289b7ec6)
  t(h, d, a, b, c, 0, 11, 0xeaa127fa)
  t(h, c, d, a, b, 3, 16, 0xd4ef3085)
  t(h, b, c, d, a, 6, 23, 0x04881d05)
  t(h, a, b, c, d, 9, 4, 0xd9d4d039)
  t(h, d, a, b, c, 12, 11, 0xe6db99e5)
  t(h, c, d, a, b, 15, 16, 0x1fa27cf8)
  t(h, b, c, d, a, 2, 23, 0xc4ac5665)

  // Round 4
  // s[48..63] := { 6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21 }
  t(i, a, b, c, d, 0, 6, 0xf4292244)
  t(i, d, a, b, c, 7, 10, 0x432aff97)
  t(i, c, d, a, b, 14, 15, 0xab9423a7)
  t(i, b, c, d, a, 5, 21, 0xfc93a039)
  t(i, a, b, c, d, 12, 6, 0x655b59c3)
  t(i, d, a, b, c, 3, 10, 0x8f0ccc92)
  t(i, c, d, a, b, 10, 15, 0xffeff47d)
  t(i, b, c, d, a, 1, 21, 0x85845dd1)
  t(i, a, b, c, d, 8, 6, 0x6fa87e4f)
  t(i, d, a, b, c, 15, 10, 0xfe2ce6e0)
  t(i, c, d, a, b, 6, 15, 0xa3014314)
  t(i, b, c, d, a, 13, 21, 0x4e0811a1)
  t(i, a, b, c, d, 4, 6, 0xf7537e82)
  t(i, d, a, b, c, 11, 10, 0xbd3af235)
  t(i, c, d, a, b, 2, 15, 0x2ad7d2bb)
  t(i, b, c, d, a, 9, 21, 0xeb86d391)
  state[0] += a.val
  state[1] += b.val
  state[2] += c.val
  state[3] += d.val
}

/// Compute the MD5 digest of some `data` based on [RFC1321](https://www.ietf.org/rfc/rfc1321.txt).
/// - Note that MD5 is considered _cryptographically broken_.
/// Unless mandated, more secure alternatives should be preferred.
pub fn md5sum(data : Bytes) -> Bytes {
  let ctx = MD5Context::make()
  md5_update(ctx, data)
  ctx.compute()
}

test "md5_wb" {
  let hash = md5sum("The quick brown fox jumps over the lazy dog".to_bytes())
  inspect!(
    bytes_to_hex_string(hash),
    content="b0986ae6ee1eefee8a4a399090126837",
  )
}

test {
  let ctx = MD5Context::make()
  md5_update(ctx, b"\x61")
  md5_update(ctx, b"\x62")
  md5_update(ctx, b"\x63")
  let res1 = bytes_to_hex_string(ctx.compute())
  let ctx = MD5Context::make()
  md5_update(ctx, b"\x61\x62\x63")
  let res2 = bytes_to_hex_string(ctx.compute())
  @test.eq!(res1, res2)
}
