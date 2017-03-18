require 'google/apis/gmail_v1'
require 'google/apis/people_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require './contact_list/google_contacts_api.rb'

require 'fileutils'

#############################################################################################
# Following: https://developers.google.com/gmail/api/quickstart/ruby                        #
#############################################################################################

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
APPLICATION_NAME = 'Gmail API Ruby Quickstart'
CLIENT_SECRETS_PATH = 'client_secret.json'

GMAIL_CREDENTIALS_PATH = File.join(Dir.home, '.credentials', 'gmail-ruby.yaml')
CONTACTS_CREDENTIALS_PATH = File.join(Dir.home, '.credentials', 'contacts-ruby.yaml')

GMAIL_SCOPE = Google::Apis::GmailV1::AUTH_GMAIL_COMPOSE
CONTACTS_SCOPE = Google::Apis::PeopleV1::AUTH_CONTACTS_READONLY

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or initiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize(scope, credentials_path)
  FileUtils.mkdir_p(File.dirname(credentials_path))

  client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: credentials_path)
  authorizer = Google::Auth::UserAuthorizer.new(
    client_id, scope, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(
      base_url: OOB_URI)
    puts 'Open the following URL in the browser and paste the ' +
           'resulting code HERE after authorization:'
    puts url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI)
  end
  credentials
end

# Initialize the API
service = Google::Apis::GmailV1::GmailService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize(GMAIL_SCOPE, GMAIL_CREDENTIALS_PATH)


# Look up contacts for a specific group. You'd need to edit the URL below for the specific group you care about
# all_groups =  ContactList::GoogleContactsApi.new(service.client, authorize(CONTACTS_SCOPE, CONTACTS_CREDENTIALS_PATH)).all_groups
# pp all_groups

PromoAlbumGroup = Struct.new(:id)
promo_album_group = PromoAlbumGroup.new('http://www.google.com/m8/feeds/groups/you%40gmail.com/base/some-uuid')

members =  ContactList::GoogleContactsApi.new(service.client, authorize(CONTACTS_SCOPE, CONTACTS_CREDENTIALS_PATH)).group_members(promo_album_group)
puts "Found #{members.length} total contacts"
members = members.uniq {|m| m.email_address}
members = members.sort
puts "Filtered to #{members.length} unique contacts (by email)"


create_draft = true

members.each do |member|
  name = member.first_name || member.full_name
  puts '-'*30
  puts name
  puts member.email_address
  # pp member

  user_id     = 'me' #('me' is a special value that denotes the currently OAuth'd user)
  format      = 'text/html'
  recipient   = member.email_address
  sender      = 'your-name@gmail.com'
  subject     = "My draft subject for #{member.full_name}"
  body        = <<-EOT
<p>Hi #{name}</p>
<p>INTRO SENTENCE.<br/>
INTRO SENTENCE TWO.</p>
<p>EXAMPLE LINK <a href='http://bit.ly/my-link'>HERE</a>.<p/>
<p>Be well</p>
EOT
  _raw        = "Content-type: #{format}\r\nTo: #{recipient}\r\nFrom: #{sender}\r\nSubject: #{subject}\r\n\r\n#{body}"

  message = Google::Apis::GmailV1::Message.new({raw: _raw})
  draft = Google::Apis::GmailV1::Draft.new({message: message})

  if create_draft
    result = service.create_user_draft(user_id, draft)
    puts "\n\n"
    puts '='*80
    puts result.inspect
    puts '_'*80
  end
end

# Can't figure this out :(
# Returns: invalidArgument: Missing draft message (Google::Apis::ClientError)

# to = Google::Apis::GmailV1::MessagePartHeader.new(name: 'To', value: 'test@domain.com')
# from = Google::Apis::GmailV1::MessagePartHeader.new(name: 'From', value: 'spatial@infrasonics.net')
# subject = Google::Apis::GmailV1::MessagePartHeader.new(name: 'Subject', value: "Test message from the CLI at : #{Time.now}")
#
# message_part_headers = [to, from, subject]
# message_part_body = Google::Apis::GmailV1::MessagePartBody.new(data: Base64.urlsafe_encode64("Test message from the CLI at : #{Time.now}"))
# message_part = Google::Apis::GmailV1::MessagePart.new({body: message_part_body, headers: message_part_headers, mime_type: 'text/html; charset=utf-8'})
#
# message = Google::Apis::GmailV1::Message.new({payload: message_part})



