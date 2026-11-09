require 'tempfile'

module SyntheticFiles
  def with_synthetic_file(root)
    Tempfile.create([ 'seedbench-synthetic-', '.txt' ], root) do |file|
      file.binmode
      file.write("Seedbench synthetic fixture\n")
      file.flush
      yield Pathname.new(file.path)
    end
  end
end
