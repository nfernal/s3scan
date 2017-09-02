require 'aws-sdk'
require 'pp'

Aws.use_bundled_cert!

region = 'us-west-2'

s3 = Aws::S3::Client.new(region: region)

resp = s3.list_objects({
  bucket: "nfernal-testbucket-#{region}",
  max_keys: 50,
})

puts resp.to_h