#
# Hash Tests (strongly dependent on the implementation)
#

RUN_SLOW_TEST = false

#
# The tests for `h_check_modified()` is not run if this variable is false
# because the nature of the allocator may cause it not to work as expected.
# However, if the test is successful even once in some environment, it can
# be said that the `h_check_modified()` implementation itself is correct.
#
# If there is a problem in the implementation of `h_check_modified()`, it
# should be detectable by valgrind or ASAN, but using them may change the
# nature of the allocator and the test may not work as expected, so it is
# not detected well.
#
RUN_H_CHECK_MODIFIED = true

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

  def initialize(value, error: nil, callback: nil, &block)
    @value = value
    @error = error
    @callback = callback
    block.(self) if block
  end

  def ==(other)
    @callback.(:==, self, other) if @callback
    return raise_error(:==) if @error == true || @error == :==
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
    raise "#{self}: ##{name} error"
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
  assert_equal(exp, params)
end

def assert_hash_internal(exp, act)
  assert 'hash internal' do
    exp.each do |k, v|
      next pass if v === act.__send__(k)
      msg = "Expected the following value of '#{k}' to be #{v.inspect}.\n" +
            act.ii
      lines = []
      msg.each_line{|line| lines << "    #{line}"}
      flunk "", lines.join
      break
    end
  end
end

def assert_modified_error(&block)
  assert_raise_with_message(RuntimeError, "hash modified", &block)
end

if RUN_H_CHECK_MODIFIED
  assert 'h_check_modified() (AR)' do
    attr_names = %i[ar? size ea ea_capacity ht ib_bit]

    # shink EA capa (unchange size and EA pointer)
    h = (1..16).to_h{[_1, _1]}
    (1..9).each{h.delete(_1)}
    exp_attrs = attr_names.to_h{[_1, h.__send__(_1)]}
    before_ea_capa = exp_attrs.delete(:ea_capacity)
    k = HashKey[0, callback: ->(*) {
      h.rehash
      assert_operator(h.ea_capacity, :<, before_ea_capa)
      assert_equal(exp_attrs, exp_attrs.to_h{|n, v| [n, h.__send__(n)]})
    }]
    assert_modified_error{h[k]}

    # change EA pointer (unchange size and EA capa)
    h = {a: 1}
    exp_attrs = attr_names.to_h{[_1, h.__send__(_1)]}
    before_ea = exp_attrs.delete(:ea)
    k = HashKey[1,callback: ->(*) {
      h.replace(a: 1)
      assert_not_equal(h.ea, before_ea)
      exp_attrs.each {|n, v| assert_equal(v, h.__send__(n))}
    }]
    assert_modified_error{h[k]}
  end

  assert 'h_check_modified() (HT)' do
    attr_names = %i[ar? size ea ea_capacity ht ib_bit]

    # shink EA capa (unchange size, IB capa, and EA/HT pointer)
    h = (1..65).to_h{[_1, _1]}
    (1..2).each{h.delete(_1)}
    exp_attrs = attr_names.to_h{[_1, h.__send__(_1)]}
    before_ea_capa = exp_attrs.delete(:ea_capacity)
    k = HashKey[0, callback: ->(*) {
      h.rehash
      assert_operator(h.ea_capacity, :<, before_ea_capa)
      assert_equal(exp_attrs, exp_attrs.to_h{|n, v| [n, h.__send__(n)]})
    }]
    assert_modified_error{h[k]}

    # shink IB capa (unchange size, EA capa, and EA/HT pointer)
    h = (1..25).to_h{[_1, _1]}
    h.delete(1)
    exp_attrs = attr_names.to_h{[_1, h.__send__(_1)]}
    before_ib_bit = exp_attrs.delete(:ib_bit)
    k = HashKey[0, callback: ->(*) {
      h.rehash
      assert_operator(h.ib_bit, :<, before_ib_bit)
      assert_equal(exp_attrs, exp_attrs.to_h{|n, v| [n, h.__send__(n)]})
    }]
    assert_modified_error{h[k]}

    # change EA pointer (unchange size, EA/IB capa, and HT pointer)
    del_keys = 26..200
    h = (1..del_keys.last).to_h{[_1, _1]}
    del_keys.each{h.delete(_1)}
    exp_attrs = attr_names.to_h{[_1, h.__send__(_1)]}
    before_ea = exp_attrs.delete(:ea)
    k = HashKey[0, callback: ->(*) {
      del_keys.each{h[_1] = _1}
      del_keys.each{h.delete(_1)}
      assert_not_equal(before_ea, h.ea)
      assert_equal(exp_attrs, exp_attrs.to_h{|n, v| [n, h.__send__(n)]})
    }]
    assert_modified_error{h[k]}

    # change HT pointer (unchange size, EA/IB capa, and EA pointer)
    h = (1..17).to_h{[_1, _1]}
    exp_attrs = attr_names.to_h{[_1, h.__send__(_1)]}
    before_ht = exp_attrs.delete(:ht)
    k = HashKey[0, callback: ->(*) {
      del_key = h.size
      h.delete(del_key)
      h.rehash
      h2 = {a: 1}  # To make the next HT allocation a different address
      h[del_key] = del_key
      assert_not_equal(before_ht, h.ht)
      assert_equal(exp_attrs, exp_attrs.to_h{|n, v| [n, h.__send__(n)]})
    }]
    assert_modified_error{h[k]}

    # h_check_modified() is not called for empty Hash object
    k = HashKey[0, error: true]
    assert_nothing_raised{{}[k]}
    assert_nothing_raised{{}[k] = 0}
    assert_nothing_raised{{}.key?(k)}
    assert_nothing_raised{{}.value?(k)}
  end
end

assert 'mrb_hash_new_capa()' do
  #  capa, [   ar,       ea, ib_bit]
  [ [   0, [ true,      nil,    nil]],
    [   1, [ true,  Numeric,    nil]],
    [   7, [ true,  Numeric,    nil]],
    [  16, [ true,  Numeric,    nil]],
    [  17, [false,  Numeric,      5]],
    [ 128, [false,  Numeric,      8]],
    [1535, [false,  Numeric,     11]],
    [1537, [false,  Numeric,     12]],
  ].each do |capa, (ar, ea, ib_bit)|
    h = HashTest.new_with_capacity(capa)
    assert_hash_internal [
      [:ar?, ar],
      [:size, 0],
      [:ea, ea],
      [:ea_capacity, capa],
      [:ea_n_used, 0],
      [:ib_bit, ib_bit],
    ], h
  end
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
    assert_nothing_raised{HashTest.dup!(h)}
  end
end

assert 'mrb_hash_fetch()' do
  [ar_entries, ht_entries].each do |entries|
    h = entries.hash_for(Hash.new(:_defval))
    assert_equal(entries.size, h.size)
    entries.each{|k, v| assert_equal(v, HashTest.fetch(h, k, "_v"))}
    assert_equal(nil, HashTest.fetch(h, "_not_found_", nil))
    assert_equal("_v", HashTest.fetch(h, "_not_found_", "_v"))
  end
end

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

  [ar_entries, ht_entries].each do |entries1|
    k1, k2 = HashKey[-1], HashKey[-2]
    h1 = entries1.push([k1, -1]).hash_for
    h2 = HashEntries[[k2, -2]].hash_for
    k1.error = true
    assert_nothing_raised{HashTest.merge(h1, h2)}
    k3, k4 = HashKey[-3], HashKey[-4]
    h1[k3] = -3
    h2[k4] = -4
    k4.error = true
    assert_raise{HashTest.merge(h1, h2)}
  end
end

assert 'Hash#[]= internal' do
  size = 0
  h = Hash.new
  assert_hash_internal [
    [:ar?, true],
    [:size, size],
    [:ea, nil],
    [:ea_capacity, 0],
    [:ea_n_used, size],
  ], h

  #1 2 3 4  5  6  7  8  9 10 11 12 13 14 15 16
  [4,4,4,4,10,10,10,10,10,10,16,16,16,16,16,16].each do |ea_capa|
    size += 1
    h[size] = true
    assert_hash_internal [
      [:ar?, true],
      [:size, size],
      [:ea_capacity, ea_capa],
      [:ea_n_used, size],
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
      [:ea_capacity, ea_capa],
      [:ea_n_used, size],
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
        [:ea_capacity, ea_capa],
        [:ea_n_used, size],
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
      [:ea_capacity, ea_capa],
      [:ea_n_used, size],
      [:ib_bit, ib_bit],
    ], h
  end
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
        [:ea_capacity, capa],
        [:ea_n_used, size],
      ], h
    end

    h[0] = 0
    assert "after set (initial size: #{size})" do
      assert_hash_internal [
        [:ar?, true],
        [:size, size],
        [:ea_capacity, capa],
        [:ea_n_used, used_sizes[i]],
      ], h
    end
  end
end

assert 'Hash#[]= with deleted internal (HT)' do
  #    init    del     add  [   ar, size,   ea      ea   ib]
  #    keys,  keys,   keys, |             capa, n_used, bit]
  [ [ 1..24,     1,     31, [false,   24,   25,     25,   5]],
    [ 1..24, 1..18, 31..31, [false,    7,   25,     25,   5]],
    [ 1..24, 1..18, 31..32, [ true,    8,   14,      8, nil]],
    [ 1..24, 1..10, 31..32, [ true,   16,   16,     16, nil]],
    [ 1..24,  1..9, 31..31, [false,   16,   25,     25,   5]],
    [ 1..25,  1..9, 31..31, [false,   17,   25,     17,   5]],
    [ 1..25,  1..9,     25, [ true,   16,   16,     16, nil]],
    [ 1..48,  1..1, 51..52, [false,   49,   49,     49,   7]],
    [ 1..48, 1..20, 51..52, [false,   30,   40,     30,   6]],
    [ 1..63, 1..15, 71..72, [false,   50,   64,     50,   7]],
    [ 1..63, 1..14, 71..72, [false,   51,   82,     65,   7]],
    [ 1..64, 1..20,     64, [false,   44,   58,     44,   7]],
    [ 1..96,  1..1, 97..98, [false,   97,  104,     97,   8]],
  ].each do |init_keys, del_keys, add_keys, (ar,size,ea_capa,ea_n_used,ib_bit)|
    h = [*init_keys].to_h{[_1, _1]}
    [*del_keys].each{h.delete(_1)}
    [*add_keys].each{h[_1] = _1 * -1}
    msg = "init_keys: #{init_keys}, del_keys: #{del_keys}, add_keys: #{add_keys}"
    assert msg do
      assert_hash_internal [
        [:ar?, ar],
        [:size, size],
        [:ea_capacity, ea_capa],
        [:ea_n_used, ea_n_used],
        [:ib_bit, ib_bit],
      ], h
    end
  end
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

assert 'Hash#clear internal' do
  [ar_entries.hash_for, ht_entries.hash_for].each do |h|
    h.clear
    assert_hash_internal [
      [:ar?, true],
      [:size, 0],
      [:ea, nil],
      [:ea_capacity, 0],
      [:ea_n_used, 0],
    ], h
  end
end

assert 'Hash#rehash internal' do
  # init keys,         del keys, [   ar, size, ea_capa, ib_bit]
  [ [    1..7,             1..7, [ true,    0,       0,    nil]],
    [    1..9,                5, [ true,    8,      10,    nil]],
    [   1..16,                1, [ true,   15,      16,    nil]],
    [   1..16,                0, [ true,   16,      16,    nil]],
    [   1..17,            1..17, [ true,    0,       0,    nil]],
    [   1..60, [*3..10,*16..59], [ true,    8,      15,    nil]],
    [   1..60,           11..53, [false,   17,      26,      5]],
    [   1..60,           11..54, [ true,   16,      16,    nil]],
    [   1..60,           11..55, [ true,   15,      16,    nil]],
    [   1..60,           25..60, [false,   24,      34,      5]],
    [   1..60,           26..60, [false,   25,      36,      6]],
  ].each do |init_keys, del_keys, (ar, size, ea_capa, ib_bit)|
    h = [*init_keys].to_h{[_1, _1]}
    [*del_keys].each{h.delete(_1)}
    h.rehash
    msg = "init_keys: #{init_keys}, del_keys: #{del_keys}"
    assert msg do
      assert_hash_internal [
        [:ar?, ar],
        [:size, size],
        [:ea, ea_capa == 0 ? nil : Numeric],
        [:ea_capacity, ea_capa],
        [:ea_n_used, size],
        [:ib_bit, ib_bit],
      ], h
    end
  end

  entries = HashEntries[*(1..25).map{[HashKey[_1], _1]}]
  h = entries.hash_for
  entries.each_key{_1.value = 1}
  assert_hash_internal [
    [:ar?, true],
    [:size, 1],
    [:ea_capacity, 4],
    [:ea_n_used, 1],
    [:ib_bit, nil],
  ], h.rehash

  entries = HashEntries[*(1..40).map{[HashKey[_1], _1]}]
  h = entries.hash_for
  (21..39).each{entries.key(_1).value = 1}
  assert_hash_internal [
    [:ar?, false],
    [:size, 21],
    [:ea_capacity, 31],
    [:ea_n_used, 21],
    [:ib_bit, 6],
  ], h.rehash

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
      [:ea_capacity, ea_capa],
      [:ea_n_used, size],
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
    [:ea_capacity, 48],
    [:ea_n_used, size],
    [:ib_bit, 6],
  ], h

  size += 1
  h[size] = size
  assert_hash_internal [
    [:ar?, false],
    [:size, size],
    [:ea_capacity, 63],
    [:ea_n_used, size],
    [:ib_bit, 7],
  ], h
end

if RUN_SLOW_TEST
  assert 'large Hash' do
    entries = (1..70000).map {|n| [n, n * 2]}
    h = {}
    size = entries.size
    n = 0; (h.store(*entries[n]); n+=1) while n < size
    assert_equal(size, h.size)
    assert_equal(entries, h.to_a)
    n = 0; (k, v = entries[n]; assert_equal(v, h[k]); n+=1) while n < size
  end
end

#assert "Hash TODO" do
#  assert_raise(FrozenError){{}.freeze.delete(1){}}
#  %i[reject! select!].each do |meth|
#    assert_raise(FrozenError){{}.freeze.__send__(meth){}}
#  end
#end
