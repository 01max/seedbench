require 'tempfile'

module UploadHelpers
  def ebook_upload(name = 'Synthetic.epub', bytes: "Synthetic ebook bytes\n")
    file = Tempfile.new([ 'synthetic-upload', File.extname(name) ])
    file.binmode
    file.write(bytes)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, 'application/octet-stream', original_filename: name)
  end
end

RSpec.configure { |config| config.include UploadHelpers }
