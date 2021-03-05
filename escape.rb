require 'set'
class FSEscape
  def self.escape(path, escape_char = '_')
      reserved_words_windows = Set.new([
          "CON", "PRN", "AUX", "NUL",
          "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
          "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
      ])
      return "#{escape_char}#{path}" if reserved_words_windows.include?(File.basename(path, ".*").upcase)
      path.gsub(%r{[/\\?%*:|"<>. ]}, escape_char)
  end
end