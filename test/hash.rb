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
  def key(index) self[index][0] end
  def value(index) self[index][1] end
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
    [nil, 1],
    [:one, 1],
    ["NIL", nil],
    [HashKey[6], :six],  # same hash code as HashKey[2]
    [HashKey[5], :five],
  ]
end

def ht_entries
  ar_entries.dup.push(
    ["id", 32],
    [:date, "2020-05-02"],
    [200, "OK"],
    ["modifiers", ["left_shift"]],
    ["key_code", "h"],
    ["h", 0x04],
    [[3, 2, 1], "three, two, one"],
    [:auto, false],
    [:path, "/path/to/file"],
    [:name, "Ruby"],
  )
end

def assert_hash_internal(exp, act)
  assert 'hash internal' do
    exp.each do |k, v|
      next pass if v == act.__send__(k)
      msg = "Expected the following value of '#{k}' to be #{v.inspect}.\n" \
            "#{act.ii}"
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
  assert_new_capa [[:ar?, true]], 7
  assert_new_capa [[:ar?, true]], 16
  assert_new_capa [[:ar?, false], [:ib_bit, 5]], 17
  assert_new_capa [[:ar?, false], [:ib_bit, 11]], 1536
  assert_new_capa [[:ar?, false], [:ib_bit, 12]], 1537
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
