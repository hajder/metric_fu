MetricFu.lib_require { 'formatter/syntax' }
MetricFu.lib_require { 'templates/template' }


module MetricFu
  module Templates
    class Report < MetricFu::Template

      def initialize(file, lines)
        @file = file
        @lines = lines
        @data = File.open(file, 'rb') {|f| f.readlines }
      end

      def render(metrics)
        @metrics = metrics
        erbify('report')
      end

      def convert_ruby_to_html(ruby_text, line_number)
        MetricFu::Formatter::Syntax.new.highlight(ruby_text, line_number)
      end

      def line_for_display(line, line_number)
        if MetricFu::Formatter::Templates.option('syntax_highlighting')
          line_for_display = convert_ruby_to_html(line, line_number)
        else
          "<a name='n#{line_number}' href='n#{line_number}'>#{line_number}</a>#{line}"
       end
      end

      def template_directory
        File.dirname(__FILE__)
      end

    end
  end
end
