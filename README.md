# Promo sender

Hacky script to iterate members in a Google Contacts group and create a templated **draft** Gmail/Inbox message for each contact. 

Start at the Google API [quickstart docs](https://developers.google.com/gmail/api/quickstart/ruby).

You'll need to customise the script but this is the rough overview:

- The script needs 2 OAuth scopes from Contacts/Gmail and assumes the APIs have been enabled (see link above)
- Running the script will require you to follow the instructions in the CLI (first run only) and open the OAuth URLs in your browser, grant access and paste the response in the CLI
- It then creates a template draft message in Gmail for each recipient in the (currently hardcoded) group. It _could_ send emails directly but I prefer a manual review/customisation process 


## Local setup

Using Ruby (tested with 2.2.0):

```bash
# install dependencies
$ gem install bundler
$ bundle install

$ ruby send.rb
```
