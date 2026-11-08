require "openssl"

key = ENV["SEEDBENCH_ENCRYPTION_KEY"]
Rails.application.config.active_record.encryption.primary_key = key
Rails.application.config.active_record.encryption.deterministic_key = OpenSSL::HMAC.hexdigest("SHA256", key, "deterministic") if key
Rails.application.config.active_record.encryption.key_derivation_salt = "seedbench-provider-credentials-v1"
