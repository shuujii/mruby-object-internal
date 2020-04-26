#
# Hash Tests (strongly dependent on the implementation)
#

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
  assert_new_capa [[:ar?, false], [:ib_bit, 10]], 768
  assert_new_capa [[:ar?, false], [:ib_bit, 11]], 769
end
