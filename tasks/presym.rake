all_prerequisites = ->(task_name, prereqs) do
  Rake::Task[task_name].prerequisites.each do |prereq_name|
    next if prereqs[prereq_name]
    prereqs[prereq_name] = true
    all_prerequisites.(Rake::Task[prereq_name].name, prereqs)
  end
end

MRuby.each_target do |build|
  gensym_task = task(:gensym)
  next unless build.presym_enabled?

  presym = build.presym

  include_dir = "#{build.build_dir}/include"
  build.compilers.each{|c| c.include_paths << include_dir}
  build.gems.each{|gem| gem.compilers.each{|c| c.include_paths << include_dir}}

  prereqs = {}
  pps = []
  mrbtest = "#{build.class.install_dir}/mrbtest"
  mrbc_build_dir = "#{build.mrbc_build.build_dir}/" if build.mrbc_build
  build.products.each do |product|
    all_prerequisites.(product, prereqs) unless product == mrbtest
  end
  prereqs.each_key do |prereq|
    next unless File.extname(prereq) == build.exts.object
    next if mrbc_build_dir && prereq.start_with?(mrbc_build_dir)
    pps << prereq.ext(build.exts.preprocessed)
  end

  file presym.list_path => pps do
    presyms = presym.scan(pps)
    current_presyms = presym.read_list if File.exist?(presym.list_path)
    update = presyms != current_presyms
    presym.write_list(presyms) if update
    presym.write_header(presyms) if update || !File.exist?(presym.header_path)
  end

  gensym_task.enhance([presym.list_path])
end
