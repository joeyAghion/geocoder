require 'geocoder/stores/base'

module Geocoder::Store
  module Mongoid
    include Base

    def self.included(base)
      base.class_eval do

        scope :geocoded, lambda {
          where(geocoder_options[:coordinates].ne => nil)
        }

        scope :not_geocoded, lambda {
          where(geocoder_options[:coordinates] => nil)
        }

        scope :near, lambda{ |location, *args|
          coords  = Geocoder::Calculations.extract_coordinates(location)
          radius  = args.size > 0 ? args.shift : 20
          options = args.size > 0 ? args.shift : {}

          # Use BSON::OrderedHash if Ruby's hashes are unordered.
          # Conditions must be in order required by indexes (see mongo gem).
          empty = RUBY_VERSION.split('.')[1].to_i < 9 ? BSON::OrderedHash.new : {}

          conds = empty.clone
          field = geocoder_options[:coordinates]
          conds[field] = empty.clone
          conds[field]["$nearSphere"]  = coords.reverse
          conds[field]["$maxDistance"] = \
            Geocoder::Calculations.distance_to_radians(radius, options[:units] || :mi)

          if obj = options[:exclude]
            conds[:_id.ne] = obj.id
          end
          criteria.where(conds)
        }
      end
    end

    ##
    # Coordinates [lat,lon] of the object.
    # This method always returns coordinates in lat,lon order,
    # even though internally they are stored in the opposite order.
    #
    def to_coordinates
      coords = send(self.class.geocoder_options[:coordinates])
      coords.is_a?(Array) ? coords.reverse : []
    end

    ##
    # Look up coordinates and assign to +latitude+ and +longitude+ attributes
    # (or other as specified in +geocoded_by+). Returns coordinates (array).
    #
    def geocode
      do_lookup(false) do |o,rs|
        r = rs.first
        unless r.coordinates.nil?
          o.send :write_attribute, self.class.geocoder_options[:coordinates], r.coordinates.reverse
        end
        r.coordinates
      end
    end

    ##
    # Look up address and assign to +address+ attribute (or other as specified
    # in +reverse_geocoded_by+). Returns address (string).
    #
    def reverse_geocode
      do_lookup(true) do |o,rs|
        r = rs.first
        unless r.address.nil?
          o.send :write_attribute, self.class.geocoder_options[:fetched_address], r.address
        end
        r.address
      end
    end
  end
end
