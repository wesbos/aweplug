shared_examples_for 'a crawler' do
  it 'may require authentication' do
    if crawler.respond_to? :authenticate_using, false
      expect { crawler.crawl }.to raise_error
    else
      expect { crawler.crawl }.to_not raise_error
    end
  end

  it 'must respond to crawl' do
    should respond_to(:crawl)
  end
end
