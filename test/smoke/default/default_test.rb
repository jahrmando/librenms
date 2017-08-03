# # encoding: utf-8

# Inspec test for recipe librenms::default

# The Inspec reference, with examples and extensive documentation, can be
# found at http://inspec.io/docs/reference/resources/

unless os.windows?
  # This is an example test, replace with your own test.
  describe user('root') do
    it { should exist }
  end
end

describe port(8080) do
  it { should be_listening }
end

describe port(3306) do
  it { should be_listening }
end

describe port(199) do
  it { should be_listening }
end
