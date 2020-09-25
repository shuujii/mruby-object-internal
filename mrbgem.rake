MRuby::Gem::Specification.new("mruby-object-internal") do |spec|
  spec.license = "MIT"
  spec.author  = "KOBAYASHI Shuji"
  spec.summary = "extensions to access Ruby object internal information"

  file "#{spec.dir}/src/hash.c.erb" => "#{MRUBY_ROOT}/src/hash.c"
end
