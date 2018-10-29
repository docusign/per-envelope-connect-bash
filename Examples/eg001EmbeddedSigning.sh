# Embedded signing ceremony
#
# Check that we're in a bash shell
if [[ $SHELL != *"bash"* ]]; then
  echo "PROBLEM: Run these scripts from within the bash shell."
fi

source ../Env.txt

#
# Step 1. Create the envelope.
#         The signer recipient includes a clientUserId setting
#
#  document 1 (pdf) has tag /sn1/ 
#  The envelope has two recipients.
#  recipient 1 - signer
#  recipient 2 - cc
#  The envelope will be sent first to the signer.
#  After it is signed, a copy is sent to the cc person.

# temp files:
request_data=$(mktemp /tmp/request-eg-001.XXXXXX)
response=$(mktemp /tmp/response-eg-001.XXXXXX)
doc1_base64=$(mktemp /tmp/eg-001-doc1.XXXXXX)

echo ""
echo "Sending the envelope request to DocuSign..."

# Fetch doc and encode
cat ../demo_documents/World_Wide_Corp_lorem.pdf | base64 > $doc1_base64
# Concatenate the different parts of the request
printf \
'{
    "emailSubject": "Please sign this document set",
    "documents": [
        {
            "documentBase64": "' > $request_data
cat $doc1_base64 >> $request_data
printf \
'",
            "name": "Lorem Ipsum",
            "fileExtension": "pdf",
            "documentId": "1"
        }
    ],
    "recipients": {
        "carbonCopies": [
            {
                "email": "{USER_EMAIL}",
                "name": "Charles Copy",
                "recipientId": "2",
                "routingOrder": "2"
            }
        ],
        "signers": [
            {
                "email": "{USER_EMAIL}",
                "name": "{USER_FULLNAME}",
                "recipientId": "1",
                "routingOrder": "1",
                "clientUserId": "1000",
                "tabs": {
                    "signHereTabs": [
                        {
                            "anchorString": "/sn1/",
                            "anchorUnits": "pixels",
                            "anchorXOffset": "20",
                            "anchorYOffset": "10"
                        }
                    ]
                }
            }
        ]
    },
    "status": "sent"
}' >> $request_data

curl --header "Authorization: Bearer {ACCESS_TOKEN}" \
     --header "Content-Type: application/json" \
     --data-binary @${request_data} \
     --request POST https://demo.docusign.net/restapi/v2/accounts/{ACCOUNT_ID}/envelopes \
     --output ${response}

echo ""
echo "Response:"
cat $response
echo ""

# pull out the envelopeId
ENVELOPE_ID=`cat $response | grep envelopeId | sed 's/.*\"envelopeId\": \"//' | sed 's/\",//' | tr -d '\r'`
echo "EnvelopeId: ${ENVELOPE_ID}"


# Step 2. Create a recipient view (a signing ceremony view)
#         that the signer will directly open in their browser to sign.
#
# The returnUrl is normally your own web app. DocuSign will redirect
# the signer to returnUrl when the signing ceremony completes.
# For this example, we'll use http://httpbin.org/get to show the 
# query parameters passed back from DocuSign

echo ""
echo "Requesting the url for the signing ceremony..."
curl --header "Authorization: Bearer {ACCESS_TOKEN}" \
     --header "Content-Type: application/json" \
     --data-binary '
{
    "returnUrl": "http://httpbin.org/get",
    "authenticationMethod": "none",
    "email": "{USER_EMAIL}",
    "userName": "{USER_FULLNAME}",
    "clientUserId": 1000,
}' \
     --request POST https://demo.docusign.net/restapi/v2/accounts/{ACCOUNT_ID}/envelopes/${ENVELOPE_ID}/views/recipient \
     --output ${response}

echo ""
echo "Response:"
cat $response
echo ""

SIGNING_CEREMONY_URL=`cat $response | grep url | sed 's/.*\"url\": \"//' | sed 's/\"//' | tr -d '\r'`
echo ""
echo "Attempting to automatically open your browser to the signing ceremony url..."
if which open > /dev/null 2>/dev/null
then
  open "$SIGNING_CEREMONY_URL"
elif which start > /dev/null
then
  start "$SIGNING_CEREMONY_URL"
fi

# cleanup
rm "$request_data"
rm "$response"
rm "$doc1_base64"

echo ""
echo ""
echo "Done."
echo ""


