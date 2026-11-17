require 'base64'

module Providers
  # Checks the account upload key with a generated image that contains no release data.
  class Postimages
    TEST_PNG = Base64.strict_decode64(
      'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAL0lEQVR4nO3OIQEAAAgDMAJRiCLUhxg3E/Ornr2kEhAQEBAQEBAQEBAQEBAQSAceIDPoavxLZhQAAAAASUVORK5CYII='
    ).freeze

    def self.check(connection:)
      page = Upload.call(connection: connection, bytes: TEST_PNG, media_type: 'image/png', name: 'seedbench-connection-test')
      CheckResult.new(status: 'passed', code: 'test_image_uploaded', message: I18n.t('messages.providers.postimages.test_image_uploaded', page: page))
    rescue Covers::Failure
      raise Failure.new('test_upload_unconfirmed', I18n.t('messages.providers.postimages.test_upload_unconfirmed')), cause: nil
    end
  end
end
