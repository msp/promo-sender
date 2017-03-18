
#Adapted from https://gist.github.com/lightman76/2357338dcca65fd390e2
module ContactList
  class GoogleContactsApi
    MAX_RESULTS = "250"

    attr_reader :client

    def initialize(client, auth)
      @client = client
      @auth = auth
    end

    def all_contacts
      process_contacts_list(fetch_contacts['feed']['entry'])
    end

    def query_contacts(search_text)
      process_contacts_list(fetch_contacts({q: search_text})['feed']['entry'])
    end

    def all_groups
      process_group_list(fetch_groups['feed']['entry'])
    end

    def group_members(group)
      group_data = fetch_contacts({group: group.id})
      process_contacts_list(group_data['feed']['entry'])
    end

    protected

    def execute(uri, options = {})
      client.get(uri, options[:parameters]) do |req|
        req.header['GData-Version'] = '3.0'
        req.header['Content-Type'] = 'application/json'
        @auth.apply!(req.header)
      end
    end

    def fetch_contacts(options = {})
      params = { 'alt' => 'json',
                 'max-results' => MAX_RESULTS }
      params[:q] = options[:q] if options[:q]
      params[:group] = options[:group] if options[:group]
      response = execute("https://www.google.com/m8/feeds/contacts/default/full",
                         parameters: params)
      JSON.parse(response.body)
    end

    def fetch_groups(options = {})
      params = { 'alt' => 'json',
                 'max-results' => '200' }
      params[:q] = options[:q] if options[:q]
      response = execute("https://www.google.com/m8/feeds/groups/default/full",
                         parameters: params)
      JSON.parse(response.body)
    end

    def process_group_list(group_list)
      (group_list || []).map do |group|
        group_cleansed = cleanse_gdata(group) #TODO: do I want to filter out anything?
        GoogleGroup.new(group_cleansed)
      end
    end

    def process_contacts_list(contact_list)
      (contact_list || []).map do |contact|
        contact_raw_data = {
          emails: extract_schema(contact['gd$email']),
          phone_numbers: extract_schema(contact['gd$phoneNumber']),
          handles: extract_schema(contact['gd$im']),
          addresses: extract_schema(contact['gd$structuredPostalAddress']),
          name_data: cleanse_gdata(contact['gd$name']),
          nickname: contact['gContact$nickname'] && contact['gContact$nickname']['$t'],
          websites: extract_schema(contact['gContact$website']),
          organizations: extract_schema(contact['gd$organization']),
          events: extract_schema(contact['gContact$event']),
          # MSP birthday: contact['gContact$birthday'].try(:[], "when")
        }.tap do |basic_data|
          # Extract a few useful bits from the basic data
          # basic_data[:full_name] = basic_data[:name_data].try(:[], :full_name)
          basic_data[:full_name] = basic_data[:name_data]
          primary_email_data = basic_data[:emails].find { |type, email| email[:primary] }
          primary_email_data = basic_data[:emails].find { |type, email| email[:home] } if !primary_email_data
          if primary_email_data
            basic_data[:primary_email] = primary_email_data.last[:address]
          end
        end
        GoogleContact.new(contact_raw_data)
      end
    end

    # Turn an array of hashes into a hash with keys based on the original hash's 'rel' values, flatten, and cleanse.
    def extract_schema(records)
      (records || []).inject({}) do |memo, record|
        key = (record['rel'] || 'unknown').split('#').last.to_sym
        # MSP value = cleanse_gdata(record.except('rel'))
        record.delete('rel')
        value = cleanse_gdata(record)
        value[:primary] = true if value[:primary] == 'true' # cast to a boolean for primary entries
        # MSP value[:protocol] = value[:protocol].split('#').last if value[:protocol].present? # clean namespace from handle protocols
        value[:protocol] = value[:protocol].split('#').last if value[:protocol] # clean namespace from handle protocols
        # MSP value = value[:$t] if value[:$t].present? # flatten out entries with keys of '$t'
        value = value[:$t] if value[:$t] # flatten out entries with keys of '$t'
        value = value[:href] if value.is_a?(Hash) && value.keys == [:href] # flatten out entries with keys of 'href'
        memo[key] = value
        memo
      end
    end

    # Transform this
    #     {"gd$fullName"=>{"$t"=>"Bob Smith"},
    #      "gd$givenName"=>{"$t"=>"Bob"},
    #      "gd$familyName"=>{"$t"=>"Smith"}}
    # into this
    #     { :full_name => "Bob Smith",
    #       :given_name => "Bob",
    #       :family_name => "Smith" }
    def cleanse_gdata(hash)
      (hash || {}).inject({}) do |m, (k, v)|
        k = k.gsub(/\Agd\$/, '') # remove leading 'gd$' on key names and switch to underscores
        k = ContactList.underscore(k)
        v = v['$t'] if v.is_a?(Hash) && v.keys == ['$t'] # flatten out { '$t' => "value" } results
        m[k.to_sym] = v
        m
      end
    end
  end

  class GoogleContact
    include Comparable
    attr_accessor :first_name, :last_name, :full_name, :email_address, :raw_data

    def initialize(raw_data)
      @raw_data = raw_data
      @first_name = raw_data && raw_data[:name_data] ? raw_data[:name_data][:given_name] : nil
      @last_name = raw_data && raw_data[:name_data] ? raw_data[:name_data][:family_name] : nil
      @full_name = raw_data && raw_data[:name_data] ? raw_data[:name_data][:full_name] : nil
      @email_address = raw_data[:primary_email] || ''
    end


    def <=>(other)
      self.email_address <=> other.email_address
    end
  end

  class GoogleGroup
    attr_accessor :title, :id, :raw_data

    def initialize(raw_data)
      @raw_data = raw_data
      @title = raw_data[:title]
      @id = raw_data[:id]
    end
  end


  # From: http://apidock.com/rails/ActiveSupport/Inflector/underscore
  def self.underscore(camel_cased_word)
    acronym_regex = /(?=a)b/
    return camel_cased_word unless camel_cased_word =~ /[A-Z-]|::/
    word = camel_cased_word.to_s.gsub(/::/, '/')
    word.gsub!(/(?:(?<=([A-Za-z\d]))|\b)(#{acronym_regex})(?=\b|[^a-z])/) { "#{$1 && '_'}#{$2.downcase}" }
    word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.tr!('-', '_')
    word.downcase!
    word
  end
end