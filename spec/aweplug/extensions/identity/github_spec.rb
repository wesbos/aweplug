require 'spec_helper'
require 'aweplug/extensions/identity/github'

describe 'Github Crawler' do
  let(:crawler) { Aweplug::Extensions::Identity::GitHub::Crawler.new }
  it_should_behave_like 'a crawler'
end
