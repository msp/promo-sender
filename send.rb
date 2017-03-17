require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require 'fileutils'

#############################################################################################
# Following: https://developers.google.com/gmail/api/quickstart/ruby                        #
#############################################################################################

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
APPLICATION_NAME = 'Gmail API Ruby Quickstart'
CLIENT_SECRETS_PATH = 'client_secret.json'
CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                             'gmail-ruby-quickstart.yaml')

# SCOPE = Google::Apis::GmailV1::AUTH_GMAIL_READONLY
SCOPE = Google::Apis::GmailV1::AUTH_GMAIL_COMPOSE

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

  client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(
    client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(
      base_url: OOB_URI)
    puts "Open the following URL in the browser and enter the " +
           "resulting code after authorization"
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
service.authorization = authorize


user_id     = 'me'
format      = 'text/html'
recipient   = 'someguy@example.com'
sender      = 'spatial@infrasonics.net'
subject     = "A subject at #{Time.now}"
body        = "Body goes here <a href='http://infrasonics.net'>LINK HERE</a> something after the embedded link <img src='http://spatial.infrasonics.net/infra12008' alt='record cover /> Text after the image."
_raw        = "Content-type: #{format}\r\nTo: #{recipient}\r\nFrom: #{sender}\r\nSubject: #{subject}\r\n\r\n#{body}"

message = Google::Apis::GmailV1::Message.new({raw: _raw})
draft = Google::Apis::GmailV1::Draft.new({message: message})

result = service.create_user_draft(user_id, draft)

puts "\n\n"
puts '='*80
puts result.inspect
puts '_'*80

# # Show the user's labels
# user_id = 'me'
# result = service.list_user_labels(user_id)
#
# puts "Labels:"
# puts "No labels found" if result.labels.empty?
# result.labels.each { |label| puts "- #{label.name}" }



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



