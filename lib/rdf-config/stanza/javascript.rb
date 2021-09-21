require 'open3'
require 'pty'
require 'expect'

$expect_verbose = true

class RDFConfig
  class Stanza
    class JavaScript < Stanza
      def initialize(config, opts = {})
        @stanza_type = 'javascript'

        super
      end

      def init_stanza
        return if File.exist?(stanza_base_dir)

        $stderr.puts "Initialize a togostanza repository."
        mkdir(output_dir)
        cmd = "npx togostanza init --name #{File.basename(stanza_base_dir)} --package-manager npm"
        $stderr.puts "Execute command: #{cmd}"
        Dir.chdir(output_dir) do
          PTY.getpty(cmd) do |i, o|
            o.sync = true

            # i.expect(/Git repository URL \(leave blank if you don't need to push to a remote Git repository\):/) do |line|
            i.expect(/Git repository URL/) do |line|
              print " (leave blank if you don't need to push to a remote Git repository): "
              o.puts STDIN.gets
            end

            i.expect(/license:/) do |line|
              print ' '
              o.puts STDIN.gets
            end
            i.gets

            i.expect(/create mode 100644 package.json/) do |line|
              puts line
            end
            # while i.eof? == false
            #   puts i.gets
            # end
          end
        end

        puts
        puts
      end

      def generate_template
        cmd = %Q/npx togostanza generate stanza #{@name} --label "#{label}" --definition "#{definition}" --type Stanza --provider RDF-config/
        $stderr.puts "Execute command: #{cmd}"
        Dir.chdir(stanza_base_dir) do
          PTY.getpty(cmd) do |i, o|
            o.sync = true

            i.expect(/license:/) do |line|
              print ' '
              o.puts STDIN.gets
            end

            i.expect(/author:/) do |line|
              print ' '
              o.puts STDIN.gets
            end

            i.expect(/address:/) do |line|
              print ' '
              o.puts STDIN.gets
            end
            i.gets

            while i.eof? == false
              puts i.gets
            end
          end
        end
      rescue Errno::ENOENT => e
        raise StanzaExecutionFailure, "#{e.message}\nMake sure Node.js is installed or npx command path is set in your PATH environment variable."
      end

      def generate_versionspecific_files
        update_index_js
      end

      def update_index_js
        output_to_file(index_js_fpath, index_js)
      end

      def metadata_hash
        stanza_usages = []
        parameters.each do |key, parameter|
          stanza_usages << { key => parameter['example'] }
        end
        stanza_usage_attr = stanza_usages.map do |usage|
          key = usage.keys.first
          %(#{key}="#{usage[key]}")
        end.join(' ')

        metadata = JSON.parse(File.read(metadata_json_fpath))
        metadata['stanza:usage'] = "<togostanza-#{@name} #{stanza_usage_attr}></togostanza-#{@name}>"

        metadata.merge(super('stanza:'))
      end

      def stanza_html
        sparql_result_html('.value')
      end

      def index_js
        parameter_lines = []
        parameters.each do |key, parameter|
          parameter_lines << %Q/#{' ' * 10}#{key}: "#{parameter['example']}",/
        end

        <<-EOS
import Stanza from 'togostanza/stanza';

export default class #{@name.split('_').map(&:capitalize).join} extends Stanza {
  async render() {
    try {
      const results = await this.query({
        endpoint: '#{sparql.endpoint}',
        template: 'stanza.rq.hbs',
        parameters: {
#{parameter_lines.join("\n")}
        }
      });

      this.renderTemplate(
        {
          template: 'stanza.html.hbs',
          parameters: {
            #{@name}: results.results.bindings
          }
        }
      );
    } catch (e) {
      console.error(e);
    }
  }
}
EOS
      end

      def before_generate
        init_stanza
      end

      def after_generate
        super
        STDERR.puts "To view the stanza, run (cd #{stanza_base_dir}; npx togostanza serve) and open http://localhost:8080/"
      end

      def index_js_fpath
        "#{stanza_dir}/index.js"
      end

      def stanza_html_fpath
        "#{stanza_dir}/templates/stanza.html.hbs"
      end

      def sparql_fpath
        "#{stanza_dir}/templates/stanza.rq.hbs"
      end

      def stanza_dir
        "#{stanza_base_dir}/stanzas/#{@name.split('_').join('-')}"
      end
    end
  end
end
