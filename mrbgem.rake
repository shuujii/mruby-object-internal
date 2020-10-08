MRuby::Gem::Specification.new("mruby-object-internal") do |spec|
  spec.license = "MIT"
  spec.author  = "KOBAYASHI Shuji"
  spec.summary = "extensions to access Ruby object internal information"

  file "#{dir}/src/hash.c.erb" => "#{MRUBY_ROOT}/src/hash.c"
  unless respond_to?(:erb, true)
    Object.autoload :ERB, 'erb'
    objs, test_objs = %w[src test].map do |src_dir|
      Dir.glob("#{dir}/#{src_dir}/*.c.erb").map do |tmplt|
        obj_dir = "#{build_dir}/#{File.dirname(tmplt.relative_path_from(dir))}"
        src = "#{obj_dir}/#{File.basename(tmplt).ext}"
        file src => tmplt do
          _pp "ERB", tmplt.relative_path, src.relative_path
          mkdir_p File.dirname(src)
          erb = ERB.new(File.read(tmplt), nil, "%-")
          erb.filename = tmplt
          File.write(src, erb.result(binding))
        end
        objfile(src.ext)
      end
    end
    build.libmruby_objs.concat(objs)
    test_objs.concat(test_objs)
  end
end
