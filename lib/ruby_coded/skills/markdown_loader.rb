# frozen_string_literal: true

require "yaml"

module RubyCoded
  module Skills
    # Loads project-local markdown skill files.
    class MarkdownLoader
      SUPPORTED_MODES = %w[chat plan agent].freeze

      def initialize(project_root:)
        @project_root = project_root
      end

      def load_files
        load_report[:entries]
      end

      def load_report
        return empty_report unless Dir.exist?(skills_dir)

        build_report(skill_paths)
      end

      private

      def empty_report
        { entries: [], invalid_count: 0, invalid_files: [] }
      end

      def build_report(paths)
        entries, invalid_files = paths.each_with_object([[], []]) do |path, memo|
          collect_report_entry(path, *memo)
        end

        {
          entries: entries,
          invalid_count: invalid_files.size,
          invalid_files: invalid_files
        }
      end

      def collect_report_entry(path, entries, invalid_files)
        parsed = parse_file(path)
        parsed ? entries << parsed : invalid_files << File.basename(path)
      end

      def skill_paths
        Dir.glob(File.join(skills_dir, "*.md"))
      end

      def skills_dir
        File.join(@project_root, ".rubycoded", "skills")
      end

      def parse_file(path)
        frontmatter, body = extract_frontmatter(File.read(path))
        return nil unless frontmatter

        build_entry(path, extract_attributes(frontmatter, body))
      rescue StandardError
        nil
      end

      def extract_attributes(frontmatter, body)
        data = YAML.safe_load(frontmatter) || {}
        {
          name: data["name"]&.strip,
          description: data["description"]&.strip,
          modes: normalize_modes(data["modes"]),
          trigger: data["trigger"]&.strip,
          priority: data["priority"],
          tags: normalize_tags(data["tags"]),
          content: body.to_s.strip
        }
      end

      def normalize_modes(value)
        Array(value).map { |mode| mode.to_s.strip.downcase }.reject(&:empty?)
      end

      def normalize_tags(value)
        Array(value).map { |tag| tag.to_s.strip }.reject(&:empty?)
      end

      def build_entry(path, attrs)
        return nil unless valid_entry?(attrs)

        attrs.merge(path: path)
      end

      def valid_entry?(attrs)
        !attrs[:name].to_s.empty? &&
          !attrs[:description].to_s.empty? &&
          !attrs[:content].to_s.empty? &&
          attrs[:modes].any? &&
          attrs[:modes].all? { |mode| SUPPORTED_MODES.include?(mode) }
      end

      def extract_frontmatter(raw)
        match = raw.match(/\A---\s*\n(.*?)\n---\s*\n?(.*)\z/m)
        return [nil, nil] unless match

        [match[1], match[2]]
      end
    end
  end
end
