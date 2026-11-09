require 'tempfile'
require_relative 'runtime_access'

module RuntimeUploads
  BYTES = 80 * 1024 * 1024

  def self.verify
    scratch = Rails.application.config.x.storage.fetch(:scratch)
    abort 'Upload buffers do not use the configured scratch volume' unless ENV.fetch('TMPDIR') == scratch.join('request-uploads').to_s
    cookies = JSON.parse(scratch.join('runtime-browser-cookies.json').read)
    page = RuntimeAccess.request(Net::HTTP::Get, '/', cookies)
    token = Nokogiri::HTML(page.body).at_css('meta[name="csrf-token"]')['content']
    Tempfile.create([ 'runtime-upload', '.epub' ], scratch.to_s) do |file|
      (BYTES / 65_536).times { file.write('x' * 65_536) }
      file.flush
      upload(file.path, cookies, token)
      verify_payloads(Digest::SHA256.file(file.path).hexdigest)
    end
    puts 'Two 80 MiB multipart uploads succeeded beyond the 256 MiB request-buffer budget; original bytes and hashes verified.'
  end

  def self.upload(path, cookies, token)
    File.open(path, 'rb') do |first|
      File.open(path, 'rb') do |second|
        request = Net::HTTP::Post.new('/uploads')
        request['Cookie'] = cookies.map { |key, value| "#{key}=#{value}" }.join('; ')
        request['Transfer-Encoding'] = 'chunked'
        request.set_form([ [ 'authenticity_token', token ],
          [ 'files[]', first, { filename: 'runtime-large-0.epub', content_type: 'application/epub+zip' } ],
          [ 'files[]', second, { filename: 'runtime-large-1.epub', content_type: 'application/epub+zip' } ] ], 'multipart/form-data')
        response = Net::HTTP.start('127.0.0.1', 3000, open_timeout: 3, read_timeout: 30, write_timeout: 30) { |http| http.request(request) }
        abort "Allowed multipart upload failed: #{response.code}" unless response.code == '303'
      end
    end
  end

  def self.verify_payloads(sha256)
    payloads = PayloadRevision.where(original_filename: %w[runtime-large-0.epub runtime-large-1.epub])
    abort 'Allowed multipart upload did not retain both files' unless payloads.count == 2
    payloads.each do |payload|
      path = Rails.application.config.x.storage.fetch(:payload).join(payload.locator)
      abort 'Multipart upload changed payload bytes' unless payload.size_bytes == BYTES && path.size == BYTES && payload.sha256 == sha256 && Digest::SHA256.file(path).hexdigest == sha256
    end
  end
end
