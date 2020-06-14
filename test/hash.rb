#
# Hash Tests (strongly dependent on the implementation)
#

RUN_SLOW_TEST = false

module Enumerable
  def to_h(&block)
    h = {}
    each{|e| h.store(*block.(e))}
    h
  end
end

class HashKey
  attr_accessor :value, :error, :callback

  self.class.alias_method :[], :new

  def initialize(value)
    @value = value
  end

  def ==(other)
    other.kind_of?(self.class) && @value == other.value
  end

  def eql?(other)
    @callback.(:eql?, self, other) if @callback
    return raise_error(:eql?) if @error == true || @error == :eql?
    other.kind_of?(self.class) && @value.eql?(other.value)
  end

  def hash
    @callback.(:hash, self) if @callback
    return raise_error(:hash) if @error == true || @error == :hash
    @value % 3
  end

  def to_s
    "#{self.class}[#{@value}]"
  end
  alias inspect to_s

  def raise_error(name)
    raise "#{self}: #{name} error"
  end
end

class HashEntries < Array
  self.class.alias_method :[], :new

  def initialize(entries) self.replace(entries) end
  def key(index, k=get=true) get ? self[index][0] : (self[index][0] = k) end
  def value(index, v=get=true) get ? self[index][1] : (self[index][1] = v) end
  def keys; map{|k, v| k} end
  def values; map{|k, v| v} end
  def each_key(&block) each{|k, v| block.(k)} end
  def each_value(&block) each{|k, v| block.(v)} end
  def dup2; self.class[*map{|k, v| [k.dup, v.dup]}] end
  def to_s; "#{self.class}#{super}" end
  alias inspect to_s

  def hash_for(hash={}, &block)
    each{|k, v| hash[k] = v}
    block.(hash) if block
    hash
  end
end

def ar_entries
  HashEntries[
    [1, "one"],
    [HashKey[2], :two],
    [nil, :two],
    [:one, 1],
    ["&", "&amp;"],
    [HashKey[6], :six],
    [HashKey[5], :five],  # same hash code as HashKey[2]
  ]
end

def ht_entries
  ar_entries.dup.push(
    ["id", 32],
    [:date, "2020-05-02"],
    [200, "OK"],
    ["modifiers", ["left_shift", "control"]],
    [:banana, :yellow],
    ["JSON", "JavaScript Object Notation"],
    [:size, :large],
    ["key_code", "h"],
    ["h", 0x04],
    [[3, 2, 1], "three, two, one"],
    [:auto, true],
    [HashKey[12], "December"],
    [:path, "/path/to/file"],
    [:name, "Ruby"],
  )
end

def merge_entries!(entries1, entries2)
  entries2.each do |k2, v2|
    entry1 = entries1.find{|k1, _| k1.eql?(k2)}
    entry1 ? (entry1[1] = v2) : (entries1 << [k2, v2])
  end
  entries1
end

def assert_iterator(exp, obj, meth)
  params = []
  obj.__send__(meth) {|param| params << param}
  assert_equal exp, params
end

def assert_hash_internal(exp, act)
  assert 'hash internal' do
    exp.each do |k, v|
      next pass if v == act.__send__(k)
      msg = "Expected the following value of '#{k}' to be #{v.inspect}.\n" +
            act.ii
      lines = []
      msg.each_line{|line| lines << "    #{line}"}
      flunk "", lines.join
      break
    end
  end
end

def assert_new_capa(exp, capa)
  exp += [[:size, 0], [:n_used, 0], [:ea_capacity, capa]]
  assert_hash_internal(exp, HashTest.new_with_capacity(capa))
end

def assert_modified_error(&block)
  assert_raise_with_message(RuntimeError, "hash modified", &block)
end

assert 'mrb_hash_new_capa()' do
  assert_new_capa [[:ar?, true], [:ea, nil]], 0
  assert_new_capa [[:ar?, true]], 1
  assert_new_capa [[:ar?, true]], 7
  assert_new_capa [[:ar?, true]], 16
  assert_new_capa [[:ar?, false], [:ib_bit, 5]], 17
  assert_new_capa [[:ar?, false], [:ib_bit, 8]], 128
  assert_new_capa [[:ar?, false], [:ib_bit, 11]], 1536
  assert_new_capa [[:ar?, false], [:ib_bit, 12]], 1537
end

assert 'mrb_hash_foreach()' do
  [ar_entries, ht_entries].each do |entries|
    h = entries.hash_for(Hash.new(-1))
    assert_equal entries, HashTest.to_a_by_foreach(h)
  end
end

assert 'mrb_hash_dup()' do
  cls = Class.new(Hash){attr_accessor :foo}
  [ar_entries, ht_entries].each do |entries|
    h1 = entries.hash_for(cls.new(61)){|h| h.foo = 23}.freeze
    h2 = HashTest.dup!(h1)
    assert_not_predicate(h2, :frozen?)
    assert_equal(h1.class, h2.class)
    assert_equal(entries, h2.to_a)
    assert_equal(nil, h2.foo)
    assert_not_operator(h2, :key?, "_not_found_")
    h2[-10] = 10
    assert_equal(10, h2[-10])
    assert_not_operator(h1, :key?, -10)

    h = entries.hash_for
    k = HashKey[-1]
    h[k] = 1
    k.callback = ->(*){h.clear}
    assert_nothing_raised{h.dup}
  end
end

# TODO: mrb_hash_fetch()

assert 'mrb_hash_merge()' do
  create_same_key = ->(entries) do
    pairs = entries.dup2
    h = pairs.hash_for
    pairs.key(-3).value = pairs.key(-1).value
    [pairs, h]
  end

  ar_pairs = HashEntries[
    [:_a, "a"],
    [HashKey[-4], :two],
    [-51, "Q"],
    [HashKey[-2], -6],
  ]
  ht_pairs = ht_entries.dup.push(
    [:_a, "_a"],
    [HashKey[-14], :c],
    [-40, "@"],
    [HashKey[-12], -16],
  )

  [[ar_pairs, ht_pairs], [ht_pairs, ar_pairs]].each do |entries1, entries2|
    pairs1, h1 = create_same_key.(entries1)
    pairs2, h2 = create_same_key.(entries2)
    HashTest.merge(h1, h2)
    assert_equal merge_entries!(pairs1, pairs2), h1.to_a

    pairs1, h1 = [], {}
    pairs2, h2 = create_same_key.(entries1)
    HashTest.merge(h1, h2)
    assert_equal merge_entries!(pairs1, pairs2), h1.to_a

    pairs1, h1 = create_same_key.(entries1)
    h2 = {}
    HashTest.merge(h1, h2)
    assert_equal pairs1, h1.to_a

    pairs, h = create_same_key.(entries1)
    HashTest.merge(h, h)
    assert_equal pairs, h.to_a

    pairs1, h1 = create_same_key.(entries1)
    h2 = {}
    assert_raise(FrozenError){HashTest.merge(h1.freeze, h2)}

    pairs1, h1 = create_same_key.(entries1)
    pairs2, h2 = create_same_key.(entries2)
    pairs2.key(-1).callback = ->(*){h1.clear}
    assert_modified_error{HashTest.merge(h1, h2)}

    pairs1, h1 = create_same_key.(entries1)
    pairs2, h2 = create_same_key.(entries2)
    pairs2.key(-1).callback = ->(*){h2.clear}
    assert_modified_error{HashTest.merge(h1, h2)}
  end
end

assert 'Hash#[]= internal' do
  size = 0
  h = Hash.new
  assert_hash_internal [
    [:ar?, true],
    [:size, size],
    [:n_used, size],
    [:ea, nil],
    [:ea_capacity, 0],
  ], h

  #1 2 3 4  5  6  7  8  9 10 11 12 13 14 15 16
  [4,4,4,4,10,10,10,10,10,10,16,16,16,16,16,16].each do |ea_capa|
    size += 1
    h[size] = true
    assert_hash_internal [
      [:ar?, true],
      [:size, size],
      [:n_used, size],
      [:ea_capacity, ea_capa],
    ], h
  end

  #  size, ea_capa, ib_bit
  [ [  17,      25,      5],
    [ 127,     130,      8],
    [ 128,     130,      8],
    [ 367,     367,      9],
    [ 368,     446,      9],
    [ 768,     792,     10],
    [ 769,     792,     11],
  ].each do |size, ea_capa, ib_bit|
    n = h.size+1; (h[n] = true; n+=1) while n <= size
    assert_hash_internal [
      [:ar?, false],
      [:size, size],
      [:n_used, size],
      [:ea_capacity, ea_capa],
      [:ib_bit, ib_bit],
    ], h
  end
end

if RUN_SLOW_TEST
  assert 'Hash#[]= internal (EA maximum increase)' do
    h = {}
    #    size, ea_capa, ib_bit
    [ [280196,  280196,     19],
      [280197,  336241,     19],
      [336242,  401776,     19],
      [401777,  467311,     20],
    ].each do |size, ea_capa, ib_bit|
      n = h.size+1; (h[n] = true; n+=1) while n <= size
      assert_hash_internal [
        [:ar?, false],
        [:size, size],
        [:n_used, size],
        [:ea_capacity, ea_capa],
        [:ib_bit, ib_bit],
      ], h
    end
  end
end

assert 'Hash#[]= internal (overwrite)' do
  #     ar, size, ea_capa, ib_bit
  [ [ true,    2,       4,    nil],
    [ true,    9,      10,    nil],
    [ true,   10,      10,    nil],
    [ true,   16,      16,    nil],
    [false,   17,      25,      5],
    [false,   24,      25,      6],  # IB expands when overwriting
    [false,   25,      25,      6],
  ].each do |ar, size, ea_capa, ib_bit|
    h = (1..size).to_h{[_1, _1]}
    h[1] = -1
    assert_hash_internal [
      [:ar?, ar],
      [:size, size],
      [:n_used, size],
      [:ea_capacity, ea_capa],
      [:ib_bit, ib_bit],
    ], h
  end
end

assert 'Hash#clear internal' do
  [ar_entries.hash_for, ht_entries.hash_for].each do |h|
    h.clear
    assert_hash_internal [
      [:ar?, true],
      [:size, 0],
      [:n_used, 0],
      [:ea, nil],
      [:ea_capacity, 0],
    ], h
  end
end

assert 'literal internal' do
  # literal use mrb_hash_new_capa()

  # literal,
  #     ar, size, ea_capa, ib_bit
  [ [{},
      true,    0,       0,    nil],
    [{a:1},
      true,    1,       1,    nil],
    [{a:1,b:1,c:1,d:1,e:1},
      true,    5,       5,    nil],
    [{a:1,b:1,c:1,d:1,e:1,f:1,g:1,h:1,i:1,j:1,k:1,l:1,m:1,n:1,o:1,p:1},
      true,   16,      16,    nil],
    [{a:1,b:1,c:1,d:1,e:1,f:1,g:1,h:1,i:1,j:1,k:1,l:1,m:1,n:1,o:1,p:1,q:1},
      false,  17,      17,      5],
  ].each do |h, ar, size, ea_capa, ib_bit|
    assert_nil h.ea if size == 0
    assert_hash_internal [
      [:ar?, ar],
      [:size, size],
      [:n_used, size],
      [:ea_capacity, ea_capa],
      [:ib_bit, ib_bit],
    ], h
  end
end

assert 'initialize(expand) IB with same key' do
  entries = HashEntries[*(1..16).map{[HashKey[_1], _1]}]
  h = entries.hash_for
  (2..(entries.size-1)).each{entries.key(_1).value = 2}
  entries << [HashKey[entries.size+1], entries.size+1]
  h.store(*entries[-1])
  assert_equal entries.size, h.size
  assert_equal entries, h.to_a
  assert_equal 1, h[HashKey[1]]
  (3..(entries.size-1)).each{assert_equal nil, h[HashKey[_1]]}
  assert_equal entries.size, h[HashKey[entries.size]]

  # When initializing(expanding) the IB, if a collision occurs, the EA is
  # not checked and is treated as a different key, so the value
  # corresponding to the first registered key is returned.
  assert_equal 2, h[HashKey[2]]
end

assert 'EA and IB expansion at the same time' do
  h = HashTest.new_with_capacity(35)
  size = 48
  (1..size).each{h[_1] = _1}
  assert_hash_internal [
    [:ar?, false],
    [:size, size],
    [:n_used, size],
    [:ea_capacity, 48],
    [:ib_bit, 6],
  ], h

  size += 1
  h[size] = size
  assert_hash_internal [
    [:ar?, false],
    [:size, size],
    [:n_used, size],
    [:ea_capacity, 63],
    [:ib_bit, 7],
  ], h
end

assert 'Hash#[]= with deleted internal (AR)' do
  #             1 2 3 4  5  6  7  8  9 10 11 12 13 14 15 16
  ea_capas   = [4,4,4,4,10,10,10,10,10,10,16,16,16,16,16,16]
  used_sizes = [2,3,4,4, 6, 7, 8, 9,10,10,12,13,14,15,16,16]  # after set

  ea_capas.each_with_index do |capa, i|
    size = i + 1
    h = (1..size).to_h{[_1, _1]}
    h.delete(size.div(2) + 1)
    assert "after delete (initial size: #{size})" do
      assert_hash_internal [
        [:ar?, true],
        [:size, size - 1],
        [:n_used, size],
        [:ea_capacity, capa],
      ], h
    end

    h[0] = 0
    assert "after set (initial size: #{size})" do
      assert_hash_internal [
        [:ar?, true],
        [:size, size],
        [:n_used, used_sizes[i]],
        [:ea_capacity, capa],
      ], h
    end
  end
end

assert 'Hash#[]= with deleted internal (HT)' do
  #   init_size, n_del, [   ar, size, n_used, ea_capa, ib_bit]
  [ [        24,     8, [false,   17,     17,      25,      5]],
    [        25,    20, [false,    6,     26,      36,      6]],
    [        48,    48, [ true,    1,      1,       4,    nil]],
    [        48,    44, [ true,    5,      5,      10,    nil]],
    [        48,    40, [ true,    9,      9,      15,    nil]],
    [        48,    32, [false,   17,     17,      25,      5]],
    [        48,    17, [false,   32,     32,      43,      6]],
    [        48,    16, [false,   33,     33,      44,      7]],
    [        48,    10, [false,   39,     39,      49,      7]],
    [        48,     1, [false,   48,     48,      49,      7]],
  ].each do |init_size, n_del, (ar, size, n_used, ea_capa, ib_bit)|
    h = (1..init_size).to_h{[_1, _1]}
    (1..n_del).each{h.delete(_1)}
    h[0] = 0
    assert "init_size: #{init_size}, n_del: #{n_del}" do
      assert_hash_internal [
        [:ar?, ar],
        [:size, size],
        [:n_used, n_used],
        [:ea_capacity, ea_capa],
        [:ib_bit, ib_bit],
      ], h
    end
  end

  # It becomes AR when size is AR_MAX_SIZE, compression, and overwriting
  h = (1..24).to_h{[_1, _1]}
  (1..8).each{h.delete(_1)}
  h[16] = -16
  assert_hash_internal [
    [:ar?, true],
    [:size, 16],
    [:n_used, 16],
    [:ea_capacity, 16],
  ], h
end

%i[each each_key each_value].each do |meth|
  assert "Hash##{meth} with modifieded key" do
    [ar_entries, ht_entries].each do |entries|
      k1, k2, k3 = HashKey[-1], HashKey[-2], HashKey[-3]
      entries.push([k1, 3], [k2, 5], [k3, 6])
      h = entries.hash_for
      k1.value = -10
      k2.value = -3
      exp = []
      entries.__send__(meth){|param| exp << param}
      assert_iterator exp, h, meth
    end
  end
end

%i[keys values].each do |meth|
  assert "Hash##{meth} with modifieded key" do
    [ar_entries, ht_entries].each do |entries|
      k1, k2, k3 = HashKey[-1], HashKey[-2], HashKey[-3]
      entries.push([k1, 3], [k2, 5], [k3, 6])
      h = entries.hash_for
      k1.value = -10
      k2.value = -3
      assert_equal entries.__send__(meth), h.__send__(meth)
    end
  end
end

if RUN_SLOW_TEST
  assert 'Large Hash' do
    entries = (1..70000).map {|n| [n, n * 2]}
    h = {}
    entries.each {|k, v| h[k] = v}
    assert_equal(entries.size, h.size)
    assert_equal(entries, h.to_a)
    entries.each {|k, v| assert_equal(v, h[k])}
  end
end

#assert "Hash TODO" do
#  assert_raise(FrozenError){{}.freeze.delete(1){}}
#  %i[reject! select!].each do |meth|
#    assert_raise(FrozenError){{}.freeze.__send__(meth){}}
#  end
#end
