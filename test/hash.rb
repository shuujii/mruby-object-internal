#
# Hash Tests (strongly dependent on the implementation)
#

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
    [HashKey[6], :six],  # same hash code as HashKey[2]
    [HashKey[5], :five],
  ]
end

def ht_entries
  ar_entries.dup.push(
    ["id", 32],
    [:date, "2020-05-02"],
    [200, "OK"],
    ["modifiers", ["left_shift", "control"]],
    ["key_code", "h"],
    ["h", 0x04],
    [[3, 2, 1], "three, two, one"],
    [:auto, true],
    [:path, "/path/to/file"],
    [:name, "Ruby"],
  )
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
  assert_hash_internal(exp, Hash.new_with_capacity(capa))
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

assert 'mrb_hash_merge()' do
  create_same_key = ->(entries) do
    pairs = HashEntries[*entries.map{|k, v| [k.dup, v]}]
    h = pairs.hash_for
    pairs.key(-3).value = pairs.key(-1).value
    [pairs, h]
  end
  merge_entries = -> (entries1, entries2) do
    entries2.each do |k2, v2|
      entry = entries1.find{|k1,_| k1.eql?(k2)}
      entry ? (entry[1] = v2) : (entries1 << [k2, v2])
    end
    entries1
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
    Hash.merge(h1, h2)
    assert_equal merge_entries.(pairs1, pairs2), h1.to_a

    pairs1, h1 = [], {}
    pairs2, h2 = create_same_key.(entries1)
    Hash.merge(h1, h2)
    assert_equal merge_entries.(pairs1, pairs2), h1.to_a

    pairs1, h1 = create_same_key.(entries1)
    h2 = {}
    Hash.merge(h1, h2)
    assert_equal pairs1, h1.to_a

    pairs, h = create_same_key.(entries1)
    Hash.merge(h, h)
    assert_equal pairs, h.to_a

    pairs1, h1 = create_same_key.(entries1)
    h2 = {}
    assert_raise(FrozenError){Hash.merge(h1.freeze, h2)}

    pairs1, h1 = create_same_key.(entries1)
    pairs2, h2 = create_same_key.(entries2)
    pairs2.key(-1).callback = ->(*){h1.clear}
    assert_raise_with_message(RuntimeError, "hash modified"){Hash.merge(h1, h2)}

    pairs1, h1 = create_same_key.(entries1)
    pairs2, h2 = create_same_key.(entries2)
    pairs2.key(-1).callback = ->(*){h2.clear}
    assert_raise_with_message(RuntimeError, "hash modified"){Hash.merge(h1, h2)}
  end
end

# TODO: mrb_hash_merge() など他の MRB_API のテストも必要

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
    (h.size+1).upto(size) {|n| h[n] = true}
    assert_hash_internal [
      [:ar?, false],
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

assert 'initialize(expand) IB with same key' do
  entries = HashEntries[*(1..16).map{[HashKey[_1], _1]}]
  h = entries.hash_for
  (2..(entries.size-1)).each{entries.key(_1).value = 2}
  entries << [HashKey[entries.size+1], entries.size+1]
  h.[]=(*entries[-1])
  assert_equal entries.size, h.size
  assert_equal entries, h.to_a
  assert_equal 1, h[HashKey[1]]
  assert_equal 2, h[HashKey[2]]
  (3..(entries.size-1)).each{assert_equal nil, h[HashKey[_1]]}
  assert_equal entries.size, h[HashKey[entries.size]]
end

#assert 'Large Hash' do
#  entries = (1..70000).map {|n| [n, n * 2]}
#  h = {}
#  entries.each {|k, v| h[k] = v}
#  assert_equal(entries.size, h.size)
#  assert_equal(entries, h.to_a)
#  entries.each {|k, v| assert_equal(v, h[k])}
#end
