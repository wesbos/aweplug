require 'spec_helper'
require 'aweplug/cache/yaml_file_cache'

describe Aweplug::YamlFileCache do
  specify 'it should respond to #write' do
    expect(subject).to respond_to :write
  end
  specify 'it should respond to #fetch' do
    expect(subject).to respond_to :fetch
  end
  specify 'it should respond to #read' do
    expect(subject).to respond_to :read
  end
  context 'with a new instance' do
    subject = Aweplug::YamlFileCache.new 
    # destroy any file stores
    before { File.delete 'tmp/cache.store' if File.exists? 'tmp/cache.store' }

    specify 'should return nil on #read' do
      expect(subject.read 'key').to be_nil
    end
    specify '#fetch with a block should return what the block returns' do
      expect(subject.fetch('key1') { 3 }).to be_eql 3
    end
    specify '#fetch should not return the default if the key is in the cache' do
      subject.write(:key_fetch, 4)
      expect(subject.fetch(:key_fetch) { 3 }).to be_eql 4
    end
    specify '#write should return the data written in yaml' do
      expect(subject.write('key3', 'data3')).to be_eql 'data3'
    end
    specify '#read after #write to return data sent via #write' do
      subject.write('key2', 'data')
      expect(subject.read('key2')).to be_eql 'data'
    end
    specify 'multiple calls to #read should return the same object' do
      key = 'id_test'
      data = 'data test'
      data_id = data.__id__
      subject.write(key, data)
      expect(subject.read(key).__id__).to be_eql data_id
      expect(subject.read(key).__id__).to be_eql data_id
      expect(subject.read(key).__id__).to be_eql data_id
      expect(subject.read(key).__id__).to be_eql data_id
    end
  end
end
