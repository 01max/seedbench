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
connection = ApplicationRecord.connection
connection.create_table(:synthetic_markers) do |table|
  table.string :payload_hash, null: false
end
connection.execute("INSERT INTO synthetic_markers (payload_hash) VALUES (#{connection.quote(Digest::SHA256.file(destination).hexdigest)})")
puts "Application image, assets, non-root storage, same-file rename, and separate databases verified."
