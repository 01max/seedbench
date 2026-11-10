require 'open3'

module CoverFixtures
  def cover_bytes(width: 600, height: 900, color: 'navy')
    code = "from PIL import Image;import sys;Image.new('RGB',(int(sys.argv[1]),int(sys.argv[2])),sys.argv[3]).save(sys.stdout.buffer,format='PNG')"
    bytes, status = Open3.capture2('python3', '-c', code, width.to_s, height.to_s, color)
    raise 'Synthetic image generation failed' unless status.success?

    bytes.b
  end

  def cover_review
    { edition_match: true, quality_reviewed: true, note: 'Édition et netteté comparées manuellement.' }
  end

  def choose_manual_cover(release, bytes: cover_bytes, review: cover_review)
    Covers::Select.call(release_id: release.id, expected_revision: release.reload.input_revision, kind: 'manual',
      attributes: { image: ebook_upload('cover.png', bytes: bytes) }, review: review)
  end
end

RSpec.configure { |config| config.include CoverFixtures }
