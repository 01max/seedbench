require 'ipaddr'
require 'resolv'

module Covers
  class PublicAddress
    DENIED = %w[0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
      192.0.0.0/24 192.0.2.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
      2001:db8::/32].map { |network| IPAddr.new(network) }.freeze

    class << self
      def call(host:)
        addresses = Resolv.getaddresses(host)
        raise Failure.new(:unsafe_url) if addresses.empty? || addresses.any? { |address| !public?(address) }

        addresses.first
      end

      private

      def public?(address)
        ip = IPAddr.new(address).native
        return false if DENIED.any? { |network| network.include?(ip) }

        ip.ipv4? || IPAddr.new('2000::/3').include?(ip)
      rescue IPAddr::InvalidAddressError
        false
      end
    end
  end
end
