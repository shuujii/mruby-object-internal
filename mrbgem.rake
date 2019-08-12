autoload :ERB, 'erb'

MRuby::Gem::Specification.new(File.basename(__dir__)) do |spec|
  spec.license = 'MIT'
  spec.author  = 'mruby developers'
  spec.summary = 'extensions to access oRuby object internal attributes'

  generated_srcs = Dir["#{dir}/src/*.erb"].map do |erb|
    src = erb.ext

    objs << "#{build_dir}/#{objfile(src.ext.relative_path_from(dir))}"

    file src => erb do |t|
      outfile, infile = src, erb
      FileUtils.mkdir_p File.dirname(outfile)
      _pp "ERB", infile.relative_path, outfile.relative_path
      erb = ERB.new(File.read(infile), nil, "%-")
      erb.filename = infile
      File.write(outfile, erb.result(instance_exec{binding}))
    end

    src
  end

  task :clean do
    FileUtils.rm_f generated_srcs, verbose: $verbose
  end
end
