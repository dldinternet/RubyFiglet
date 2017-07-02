class String
  def to_utf8
    str = self.force_encoding("UTF-8")
    return str if str.valid_encoding?
    str = str.force_encoding("BINARY")
    str.encode("UTF-8", invalid: :replace, undef: :replace)
  end

  def delete_at! n
    slice! n
    self
  end
  def delete_at n
    dup.delete_at! n
  end
end

module FigFont
  WD = File.dirname(__FILE__)
  class Figlet
    def initialize font
      unless Dir.entries("#{WD}/fonts").include? "#{font}.flf"
        puts "Font not found!"
        exit 1
      end
      @fontName = font
    end

    private def scan
      contents = File.open("#{WD}/fonts/#{@fontName}.flf").read.to_utf8
      lines = contents.split "\n"
      unless lines[0].include? "flf2a"
        puts "Invalid FIGlet v2.0 font.\nThis font is not compatible with this interpreter!"
        exit 1
      end

      meta = lines[0].split " "
      @hardblank = meta[0][5];
      @height    = meta[1].to_i
      @baseline  = meta[2].to_i
      @max_len   = meta[3].to_i
      @old_lay   = meta[4].to_i
      @commented = meta[5].to_i
      # defaults, currently not used
      @print_way = 0
      @full_lay  = 64
      @tag_count = 229
      if meta.size > 6 # overide defaults
        @print_way = meta[6].to_i
        @full_lay  = meta[7].to_i
        @tag_count = meta[8].to_i
      end
      # we've got the information, now delete it form the `lines`
      (0..@commented).each { lines.delete_at 0 } # This bugger,
                                                # since I delete the first line
                                                # the next line has now become
                                                # the first line, embarrassing how long that took.
      endmark = lines[0][lines[0].length - 1]
      (0..lines.size - 1).each do |i|
        lines[i].gsub!(endmark, "")
      end

      char_hash = Hash.new
      (32..126).each do |code|
        char_hash[code.chr] = Array.new(@height, String.new)
      end # Much shorter than manually writing out every value

      char_hash.merge!({
        'Ä' => Array.new(@height, String.new),
        'Ö' => Array.new(@height, String.new),
        'Ü' => Array.new(@height, String.new),
        'ä' => Array.new(@height, String.new),
        'ö' => Array.new(@height, String.new),
        'ü' => Array.new(@height, String.new),
        'ß' => Array.new(@height, String.new)
      }) if lines.length > 95 * @height

      char_hash.each do |key, value|
        (0..@height - 1).each do |line|
          char_hash[key][line] = lines[line]
        end
        lines.slice! 0..@height - 1
      end

      smush! char_hash, lines
      char_hash.each do |key, arr|
        (0..@height - 1).each { |i| char_hash[key][i] = arr[i].gsub(@hardblank, " ") }
      end
      return char_hash
    end

    private def smush hash, lines
      hash.each do |letter, letter_arr|
        (0..lines.min_by(&:length).length - 1).each do |over| # from 0 to the length of the shortest line in the array
          same_at_index = Array.new(@height - 1, false)
          (0..@height - 2).each do |down|
            same_at_index[down] = true if (letter_arr[over][down] == letter_arr[over][down + 1]) && (letter_arr[over][down] == ' ' && letter_arr[over][down + 1] == ' ')
          end
          if same_at_index.all?
            (0..@height - 1).each do |down|
              hash[letter][down].delete_at! over
            end
          end
        end  # Pre-word smushing for each letter, when there is a consective vertical line of spaces, then smush them away
      end
      hash
    end

    private def smush! hash, lines
      hash.replace smush hash, lines
    end

    def font_data
      {
        'lookup_table': scan,
        'height': @height,
        'direction': @print_way,
        'old_layout': @old_lay,
        'full_layout': @full_lay
      }
    end
  end
end
