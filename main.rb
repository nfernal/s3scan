require 'aws-sdk'
require 'pp'

Aws.use_bundled_cert!

AWS_REGIONS = %w(us-east-1 us-east-2 us-west-1 us-west-2 )
OUT_FILE = "#{Dir.pwd}/outifle.txt".freeze

File.delete(OUT_FILE) if File.exist?(OUT_FILE)

# Returns an array of all buckets that exist in the specified region of your AWS account.
def list_buckets(client, aws_region)
  bucket_arr = []
  # list_buckets will return all buckets regardless of the region that your client is configured to.
  # This is not ideal because you'll get errors with other methods if you try to act on a bucket that's not
  # actually in the region.
  resp = client.list_buckets
  resp.buckets.map(&:name).each do |bucket_name|
    # Checking the 'actual' region of the bucket.  All regions return a region name except for us-east-1
    # which just return an empty string(WTF Amazon?!). Now I'm testing for empty string and updating to us-east-1.
    if client.get_bucket_location(bucket: bucket_name).location_constraint.empty?
      actual_region = 'us-east-1'
    else
      actual_region = client.get_bucket_location(bucket: bucket_name).location_constraint
    end
    # Filtering for the buckets that ACTUALLY exist in the configured region.
    if aws_region == actual_region
      bucket_arr << bucket_name
    end
  end
  # returning an array of bucket names.
  bucket_arr
end

# S3 ACLs are are stored as an array of 'grants'.  This function will iterate over the grants
# and search for grantee types of 'Group' that are NOT LogDelivery
def scan_bucket_acl(client, bucket_name, outfile)
  acl = client.get_bucket_acl(bucket: bucket_name)
  acl[:grants].each do |grant|
    if grant[:grantee][:type] == 'Group' && grant[:grantee][:uri] != 'http://acs.amazonaws.com/groups/s3/LogDelivery'
      puts "#{bucket_name} is open to the public!!!!"
      # sending bucket names to an outfile that can be used in Go pipeline.
      File.open(outfile.to_s, 'a') {|file| file.write("#{bucket_name}\n")}
    end
  end
end

# iteration through through the regions, get a list of buckets in each region and scanning for bad acls on those buckets.
AWS_REGIONS.each do |region|
  s3 = Aws::S3::Client.new(region: region)
  (list_buckets(s3, region)).each do |bucket|
    begin
      scan_bucket_acl(s3, bucket, OUT_FILE)
    rescue Aws::S3::Errors::PermanentRedirect, Aws::S3::Errors::AccessDenied
      next
    end
  end
end

