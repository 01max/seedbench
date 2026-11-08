require "digest"
require "net/http"

abort "Runtime must be unprivileged" if Process.uid.zero?
abort "Image contains operator material" if %w[/app/.env /app/.git /app/private /app/tmp/ebooks].any? { |path| File.exist?(path) }
abort "Provider key leaked into runtime" if ENV.key?("C411_API_KEY") || ENV.key?("OPENAI_API_KEY")

response = Net::HTTP.get_response(URI("http://127.0.0.1:3000/"))
abort "Application shell failed" unless response.code == "200" && response.body.include?("Seedbench")
assets = response.body.scan(%r{/assets/[^"<>\s]+}).uniq
abort "Assets missing" if assets.empty?
assets.each do |path|
  abort "Asset failed: #{path}" unless Net::HTTP.get_response(URI("http://127.0.0.1:3000#{path}")).code == "200"
end

root = Rails.application.config.x.storage.fetch(:payload)
source = root.join("synthetic-staging.bin")
destination = root.join("synthetic-payload.bin")
File.binwrite(source, "Seedbench synthetic durable payload\n")
inode = source.stat.ino
File.rename(source, destination)
abort "Rename changed file identity" unless destination.stat.ino == inode
release = Releases::Create.call(title: "Synthetic runtime book", author: "Test author")
PayloadRevision.create!(release: release, number: 1, original_filename: "synthetic.epub", format: "epub",
  size_bytes: destination.size, sha256: Digest::SHA256.file(destination).hexdigest, locator: destination.basename.to_s)
ContentRevision.create!(release: release, kind: "bbcode", number: 1, body: "Preserved human content", origin: "human", input_revision: 0)
Rails.application.config.x.storage.fetch(:scratch).join("runtime-release-id").write(release.id.to_s)
begin
  ApplicationRecord.connection.execute("UPDATE release_events SET name = 'changed'")
  abort "Loaded SQL schema lost its history guard"
rescue ActiveRecord::StatementInvalid => error
  raise unless error.message.include?("append-only")
end
puts "Application image, assets, SQL history guards, domain state and same-file rename verified."
