class DocxInspector
  IGNORED_FILE_LIST = {"fontTable" => 0, "numbering" => 0, "settings" => 0, "styles" => 0, "webSettings" => 0}
  DOCX_WORD_DIRECTORY_FILENAME_CAPTURE_PATTERN = /^word\/([^\/]*)\.xml/ # Capture the file name of a file in the docx's word/ directory not in a directory below word

  def initialize(docx_contents: nil, docx_path: nil)
    docx_file = nil

    if !docx_contents.nil?
      docx_file = store_docx_contents_in_tempfile(docx_contents)
    elsif !docx_path.nil?
      docx_file = File.open(docx_path, "r")
    else
      raise ArgumentError.new("Insufficient parameters. Either docx_contents or docx_path is required.")
    end

    @docx_zip_object = get_docx_as_zip_object(docx_file)

    @word_lists_by_document_section = {document: [], endnotes: [], footnotes: [], footer: [], header: []}

    get_docx_readable_text_XML_files.each do |file|
      puts file.name

      file_name = file.name.match(DOCX_WORD_DIRECTORY_FILENAME_CAPTURE_PATTERN).captures[0]
      viewable_strings = get_displayed_text_list(get_XML_object(file))

      case file_name
        when /^document/
          @word_lists_by_document_section[:document].concat(viewable_strings)
        when /^endnotes/
          @word_lists_by_document_section[:endnotes].concat(viewable_strings)
        when /^footnotes/
          @word_lists_by_document_section[:footnotes].concat(viewable_strings)
        when /^footer/
          @word_lists_by_document_section[:footer].concat(viewable_strings)
        when /^header/
          @word_lists_by_document_section[:header].concat(viewable_strings)
      end
    end

    @word_lists_by_document_section.each do |section, word_list|
      sort_string_list_by_length_ascending(word_list)
    end
  end

  def contains_str?(str)
    # Sort w:t s by length and keep array on instance
  end

  def get_word_list_all
    sort_string_list_by_length_ascending(
      @word_lists_by_document_section[:document] +
      @word_lists_by_document_section[:endnotes] +
      @word_lists_by_document_section[:footnotes] +
      @word_lists_by_document_section[:footer] +
      @word_lists_by_document_section[:header]
    )
  end

  private

  def get_displayed_text_list(xml_object)
    xml_object.xpath("//w:t/text()").filter_map do |word_text_element|
      stripped_text = word_text_element.text.strip
      stripped_text if stripped_text.length > 0
    end
  end

  def get_docx_as_zip_object(docx_file)
    Zip::File.open(docx_file.path)
  end

  def get_docx_readable_text_XML_files
    if @docx_zip_object.nil?
      raise "Required variable @docx_zip_object is uninitialized"
    end

    @docx_zip_object.entries.select do |entry|
      entry_name = entry.name
      is_ignored_file = false
      xml_file_in_word_match = entry_name.match(DOCX_WORD_DIRECTORY_FILENAME_CAPTURE_PATTERN)

      unless xml_file_in_word_match.nil?
        xml_file_name = xml_file_in_word_match.captures[0]
        is_ignored_file = !IGNORED_FILE_LIST[xml_file_name].nil?
      end

      !(xml_file_in_word_match.nil? || is_ignored_file)
    end
  end

  def get_XML_object(xml_file_as_docx_zip_entry)
    Nokogiri::XML(xml_file_as_docx_zip_entry.get_input_stream.read)
  end

  def sort_string_list_by_length_ascending(str_list)
    str_list.sort_by!(&:length)
  end

  def store_docx_contents_in_tempfile(docx_contents)
    Tempfile.create("court_report.zip", "tmp") do |file|
      file << docx_contents.force_encoding("UTF-8")

      return file
    end
  end
end
