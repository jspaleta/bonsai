# An ActiveStorage analyzer that extracts any README content from gzipped tar file.
# See the documentation for the base +ActiveStorage::Analyzer+ class.

require 'rubygems/package'
require 'zlib'


class TarBallAnalyzer < ActiveStorage::Analyzer
  include ExtractsReadmeFiles

  MIME_TYPES = %w[
    application/gzip
    application/x-compressed-tar
  ]

  def self.accept?(blob)
    MIME_TYPES.include? blob.content_type.to_s
  end

  def metadata
    content, extension = fetch_readme_from_blob

    {
      readme:           content,
      readme_extension: extension,
    }.compact
  end

  private

  def fetch_readme_from_blob
    download_blob_to_tempfile do |file|
      Gem::Package::TarReader.new(Zlib::GzipReader.open(file)) do |files|
        return extract_readme(files: files, path_method: :full_name, file_reader: self.method(:tarred_file_reader))
      end
    end
  rescue
    #:nocov:
    return [nil, nil]
    #:nocov:
  end

  def tarred_file_reader(files, file_path)
    files.rewind
    files.seek(file_path) { |file| file.read }
  end
end