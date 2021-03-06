require 'stackbuilder/support/hiera_provider'
require 'tmpdir'
require 'open3'
require 'stackbuilder/stacks/factory'
require 'fileutils'

class GivenHieradata
  def initialize(dir)
    @dir = dir
  end

  def file(name, &block)
    GivenFile.new(@dir, name).instance_eval(&block)
  end
end

class GivenFile
  def initialize(dir, filename)
    @dir = dir
    @filename = filename
  end

  def contents(contents)
    path = @dir + '/' + @filename
    dirname = File.dirname(path)
    FileUtils.mkdir_p(dirname) unless File.directory?(dirname)

    File.write(path, contents)
  end
end

describe Support::HieraProvider do
  before(:each) do
    @tmpdir = Dir.mktmpdir
    @hiera_provider = Support::HieraProvider.new(:origin => @tmpdir)
  end

  after(:each) do
    FileUtils.remove_dir(@tmpdir)
  end

  def given_hieradata(&block)
    Dir.chdir(@tmpdir) do
      ENV['GIT_AUTHOR_NAME'] = 'Test'
      ENV['GIT_COMMITTER_NAME'] = 'Test'
      ENV['GIT_AUTHOR_EMAIL'] = 'test@example.com'
      ENV['GIT_COMMITTER_EMAIL'] = 'test@example.com'
      system_call('git', 'init')
      File.write('unused_empty_file_to_ensure_git_commit', '')
      GivenHieradata.new(@tmpdir + '/hieradata').instance_eval(&block)
      system_call('git', 'add', '--all')
      system_call('git', 'commit', '--message', 'initial commit')
    end
  end

  def system_call(*cmd)
    if cmd.last.is_a?(Hash)
      opts = cmd.pop.dup
    else
      opts = {}
    end

    _stdout_str, stderr_str, status = Open3.capture3(*cmd, opts)
    fail "System call failed - error: #{stderr_str}" if !status.success?
  end

  it "should raise exception if scope doesn't contain required variables" do
    expect { @hiera_provider.lookup({}, 'anything') }.to raise_error(RuntimeError, /Missing variable/)
  end

  it "should raise exception if it can't clone the repo" do
    expect { Support::HieraProvider.new(:origin => "ce nest pas un directory").hieradata }.to raise_error(RuntimeError, /Unable to clone/)
  end

  it 'should raise exception if key not found and no default passed' do
    given_hieradata {}

    scope = {
      'domain' => 'dummy',
      'hostname' => 'dummy',
      'logicalenv' => 'dummy',
      'stackname' => 'dummy'
    }

    expect { @hiera_provider.lookup(scope, 'key/that/does/not/exist') }.to raise_error(RuntimeError, /Could not find data item/)
  end

  it 'can look up hiera values' do
    given_hieradata do
      file 'logicalenv_e1.yaml' do
        contents <<EOF
---
first/key: 'the_value'
second/key: 42
EOF
      end
    end

    scope = {
      'domain' => 'dummy',
      'hostname' => 'dummy',
      'logicalenv' => 'e1',
      'stackname' => 'dummy'
    }

    value = @hiera_provider.lookup(scope, 'first/key')

    expect(value).to eq('the_value')
  end

  it 'can fall back to files lower in the hierarchy' do
    given_hieradata do
      file 'logicalenv_e1.yaml' do
        contents <<EOF
---
not/the/answer: 'RBBoT'
EOF
      end
      file 'common.yaml' do
        contents <<EOF
---
the/answer: 42
EOF
      end
    end

    scope = {
      'domain' => 'dummy',
      'hostname' => 'dummy',
      'logicalenv' => 'e1',
      'stackname' => 'dummy'
    }

    value = @hiera_provider.lookup(scope, 'the/answer')

    expect(value).to eq(42)
  end

  it 'returns default value if key not found in data files' do
    given_hieradata {}

    scope = {
      'domain' => 'dummy',
      'hostname' => 'dummy',
      'logicalenv' => 'dummy',
      'stackname' => 'dummy'
    }

    value = @hiera_provider.lookup(scope, 'the/answer', 42)

    expect(value).to eq(42)
  end

  it 'can handle boolean values' do
    given_hieradata do
      file 'domain_mgmt.oy.net.local.yaml' do
        contents <<EOF
---
thats/the/t: true
that/aint/the/t: false
EOF
      end
      file 'common.yaml' do
        contents <<EOF
---
thats/the/t: false
that/aint/the/t: true
EOF
      end
    end

    scope = {
      'domain' => 'mgmt.oy.net.local',
      'hostname' => 'dummy',
      'logicalenv' => 'dummy',
      'stackname' => 'dummy'
    }

    true_value = @hiera_provider.lookup(scope, 'thats/the/t')
    false_value = @hiera_provider.lookup(scope, 'that/aint/the/t')

    expect(true_value).to eq(true)
    expect(false_value).to eq(false)
  end

  it 'creates hierarchy based on folders' do
    given_hieradata do
      file 'mgmt.oy.net.local/experiment-foo-bar.yaml' do
        contents <<EOF
---
river: nile
EOF
      end
      file 'common.yaml' do
        contents <<EOF
---
river: amazon
EOF
      end
    end

    scope = {
      'domain' => 'mgmt.oy.net.local',
      'hostname' => 'experiment-foo-bar',
      'logicalenv' => 'dummy',
      'stackname' => 'dummy'
    }

    value = @hiera_provider.lookup(scope, 'river')

    expect(value).to eq('nile')
  end
end
