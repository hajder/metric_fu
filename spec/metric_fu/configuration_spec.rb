require "spec_helper"

describe MetricFu::Configuration do

  def get_new_config
    ENV['CC_BUILD_ARTIFACTS'] = nil
    @config = MetricFu.configuration
    @config.reset
    MetricFu.configuration.configure_metric(:rcov) do |rcov|
      rcov.enabled = true
    end
    MetricFu.configure
    allow(MetricFu::Io::FileSystem).to receive(:create_directories) # no need to create directories for the tests
    @config
  end

  def directory(name)
    MetricFu::Io::FileSystem.directory(name)
  end

  def base_directory
    directory('base_directory')
  end

  def output_directory
    directory('output_directory')
  end

  def scratch_directory
    directory('scratch_directory')
  end

  def template_directory
    directory('template_directory')
  end

  def template_class
    MetricFu::Formatter::Templates.option('template_class')
  end

  def metric_fu_root
    directory('root_directory')
  end
  def load_metric(metric)
    load File.join(MetricFu.metrics_dir, metric, 'init.rb')
  end

  describe '#is_cruise_control_rb? ' do

    before(:each) { get_new_config }
    describe "when the CC_BUILD_ARTIFACTS env var is not nil" do

      before(:each) do
        ENV['CC_BUILD_ARTIFACTS'] = 'is set'
      end

      it 'should return true'  do
        expect(@config.is_cruise_control_rb?).to be_truthy
      end

      after(:each)  do
        ENV['CC_BUILD_ARTIFACTS'] = nil
        FileUtils.rm_rf(File.join(MetricFu.root_dir, 'is set'))
      end

    end

    describe "when the CC_BUILD_ARTIFACTS env var is nil" do
      before(:each) { ENV['CC_BUILD_ARTIFACTS'] = nil }

      it 'should return false' do
        expect(@config.is_cruise_control_rb?).to be_falsey
      end
    end
  end

  describe "#reset" do

    describe 'when there is a CC_BUILD_ARTIFACTS environment variable' do

      before do
        ENV['CC_BUILD_ARTIFACTS'] = 'foo'
        @config = MetricFu.configuration
        @config.reset
        MetricFu.configure
      end
      it 'should return the CC_BUILD_ARTIFACTS environment variable' do
        compare_paths(base_directory, ENV['CC_BUILD_ARTIFACTS'])
      end
      after do
        ENV['CC_BUILD_ARTIFACTS'] = nil
        FileUtils.rm_rf(File.join(MetricFu.root_dir, 'foo'))
      end
    end

    describe 'when there is no CC_BUILD_ARTIFACTS environment variable' do

      before(:each) do
        ENV['CC_BUILD_ARTIFACTS'] = nil
        get_new_config
      end
      it 'should return "tmp/metric_fu"' do
        expect(base_directory).to eq(MetricFu.artifact_dir)
      end

      it 'should set @metric_fu_root_directory to the base of the '+
      'metric_fu application' do
        app_root = File.join(File.dirname(__FILE__), '..', '..')
        app_root_absolute_path = File.expand_path(app_root)
        metric_fu_absolute_path = File.expand_path(metric_fu_root)
        expect(metric_fu_absolute_path).to eq(app_root_absolute_path)
      end

      it 'should set @template_directory to the lib/templates relative '+
      'to @metric_fu_root_directory' do
        template_dir = File.join(File.dirname(__FILE__),
                                 '..', '..', 'lib','templates')
        template_dir_abs_path = File.expand_path(template_dir)
        calc_template_dir_abs_path = File.expand_path(template_directory)
        expect(calc_template_dir_abs_path).to eq(template_dir_abs_path)
      end

      it 'should set @scratch_directory to scratch relative '+
      'to @base_directory' do
        scratch_dir = MetricFu.scratch_dir
        expect(scratch_directory).to eq(scratch_dir)
      end

      it 'should set @output_directory to output relative '+
      'to @base_directory' do
        output_dir = MetricFu.output_dir
        expect(output_directory).to eq(output_dir)
      end

      it 'should set @template_class to MetricFu::Templates::MetricsTemplate by default' do
        expect(template_class).to eq(MetricFu::Templates::MetricsTemplate)
      end

      describe 'when a templates configuration is given' do

        before do
          class DummyTemplate;end

          @config.templates_configuration do |config|
            config.template_class = DummyTemplate
            config.link_prefix = 'http:/'
            config.syntax_highlighting = false
            config.darwin_txmt_protocol_no_thanks = false
          end
        end

        it 'should set given template_class' do
          expect(template_class).to eq(DummyTemplate)
        end

        it 'should set given link_prefix' do
          expect(MetricFu::Formatter::Templates.option('link_prefix')).to eq('http:/')
        end

        it 'should set given darwin_txmt_protocol_no_thanks' do
          expect(MetricFu::Formatter::Templates.option('darwin_txmt_protocol_no_thanks')).to be_falsey
        end

        it 'should set given syntax_highlighting' do
          expect(MetricFu::Formatter::Templates.option('syntax_highlighting')).to be_falsey
        end

      end

      it 'should set @flay to {:dirs_to_flay => @code_dirs}' do
        load_metric 'flay'
        expect(MetricFu::Metric.get_metric(:flay).run_options).to eq(
                {:dirs_to_flay => ['lib'], :filetypes=>["rb"], :minimum_score=>nil}
        )
      end

      it 'should set @reek to {:dirs_to_reek => @code_dirs}' do
        load_metric 'reek'
        expect(MetricFu::Metric.get_metric(:reek).run_options).to eq(
                {:config_file_pattern=>nil, :dirs_to_reek => ['lib']}
        )
      end

      it 'should set @roodi to {:dirs_to_roodi => @code_dirs}' do
        load_metric 'roodi'
        expect(MetricFu::Metric.get_metric(:roodi).run_options).to eq(
                { :dirs_to_roodi => directory('code_dirs'),
                    :roodi_config => "#{directory('root_directory')}/config/roodi_config.yml"}
                )
      end

      it 'should set @churn to {}' do
        load_metric 'churn'
        expect(MetricFu::Metric.get_metric(:churn).run_options).to eq(
                { :start_date => %q("1 year ago"), :minimum_churn_count => 10, :ignore_files=>[], :data_directory=> MetricFu::Io::FileSystem.scratch_directory('churn')}
        )
      end


      it 'should set @rcov to ' +
                            %q(:test_files =>  Dir['{spec,test}/**/*_{spec,test}.rb'],
                            :rcov_opts => [
                              "--sort coverage",
                              "--no-html",
                              "--text-coverage",
                              "--no-color",
                              "--profile",
                              "--exclude-only '.*'",
                              '--include-file "\Aapp,\Alib"',
                              "-Ispec"
                            ]) do
        load_metric 'rcov'
        expect(MetricFu::Metric.get_metric(:rcov).run_options).to eq(
                { :environment => 'test',
                            :external => nil,
                            :test_files =>  Dir['{spec,test}/**/*_{spec,test}.rb'],
                            :rcov_opts => [
                              "--sort coverage",
                              "--no-html",
                              "--text-coverage",
                              "--no-color",
                              "--profile",
                              "--exclude-only '.*'",
                              '--include-file "\Aapp,\Alib"',
                              "-Ispec"
                            ],
                            }
        )
      end

      it 'should set @saikuro to { :output_directory => @scratch_directory + "/saikuro",
                                   :input_directory => @code_dirs,
                                   :cyclo => "",
                                   :filter_cyclo => "0",
                                   :warn_cyclo => "5",
                                   :error_cyclo => "7",
                                   :formater => "text" }' do
        load_metric 'saikuro'
        expect(MetricFu::Metric.get_metric(:saikuro).run_options).to eq(
                { :output_directory => "#{scratch_directory}/saikuro",
                      :input_directory => ['lib'],
                      :cyclo => "",
                      :filter_cyclo => "0",
                      :warn_cyclo => "5",
                      :error_cyclo => "7",
                      :formater => "text"}
                      )
      end

      if MetricFu.configuration.mri?
        it 'should set @flog to {:dirs_to_flog => @code_dirs}' do
          load_metric 'flog'
          expect(MetricFu::Metric.get_metric(:flog).run_options).to eq({
            :all => true,
           :continue => true,
           :dirs_to_flog => ["lib"],
           :quiet => true
           })
        end
        it 'should set @cane to ' +
                            %q(:dirs_to_cane => @code_dirs, :abc_max => 15, :line_length => 80, :no_doc => 'n', :no_readme => 'y') do
          load_metric 'cane'
          expect(MetricFu::Metric.get_metric(:cane).run_options).to eq(
            {
              :dirs_to_cane => directory('code_dirs'),
              :filetypes => ["rb"],
              :abc_max => 15,
              :line_length => 80,
              :no_doc => "n",
              :no_readme => "n"}
              )
        end
      end


    end
    describe 'if #rails? is true ' do

      before(:each) do
        @config = MetricFu.configuration
        allow(@config).to receive(:rails?).and_return(true)
        @config.reset
        MetricFu.configure
        %w(rails_best_practices).each do |metric|
          load_metric metric
        end
      end

      describe '#set_graphs ' do
        it 'should set the graphs to include rails_best_practices' do
          expect(MetricFu::Metric.get_metric(:rails_best_practices).has_graph?).to be_truthy
        end
      end

      it 'should set @rails_best_practices to {}' do
        load_metric 'rails_best_practices'
        expect(MetricFu::Metric.get_metric(:rails_best_practices).run_options).to eql({})
      end
    end

    describe 'if #rails? is false ' do
      before(:each) do
        get_new_config
        allow(@config).to receive(:rails?).and_return(false)
        %w(rails_best_practices).each do |metric|
          load_metric metric
        end
      end

      it 'should set the registered code_dirs to ["lib"]' do
        expect(directory('code_dirs')).to eq(['lib'])
      end
    end
  end

  describe '#platform' do

    before(:each) { get_new_config }

    it 'should return the value of the PLATFORM constant' do
      this_platform = RUBY_PLATFORM
      expect(@config.platform).to eq(this_platform)
    end
  end

  describe '#configure_formatter' do
    before(:each) { get_new_config }

    context 'given a built-in formatter' do
      before do
        @config.configure_formatter('html')
      end

      it 'adds to the list of formatters' do
        expect(@config.formatters.first).to be_an_instance_of(MetricFu::Formatter::HTML)
      end
    end

    context 'given a custom formatter by class name' do
      before do
        stub_const('MyCustomFormatter', Class.new() { def initialize(*); end })
        @config.configure_formatter('MyCustomFormatter')
      end

      it 'adds to the list of formatters' do
        expect(@config.formatters.first).to be_an_instance_of(MyCustomFormatter)
      end
    end

    context 'given multiple formatters' do
      before do
        stub_const('MyCustomFormatter', Class.new() { def initialize(*); end })
        @config.configure_formatter('html')
        @config.configure_formatter('yaml')
        @config.configure_formatter('MyCustomFormatter')
      end

      it 'adds each to the list of formatters' do
        expect(@config.formatters.count).to eq(3)
      end
    end
  end
end
