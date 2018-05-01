# Trie tree class
class TrieTree
  require 'natto'
  require 'romaji'
  require 'active_support'
  require 'active_support/core_ext'
  # char type https://github.com/buruzaemon/natto/wiki/Node-Parsing-char_type#appendix-d-node-parsing-and-char_type
  DEFAULT = 0
  SPACE = 1
  KANJI = 2
  SYMBOL = 3
  NUMERIC = 4
  ALPHA = 5
  HIRAGANA = 6
  KATAKANA = 7
  KANJINUMERIC = 8 # 漢字数字
  GREEK = 9 # ギリシャ文字
  CYRILLIC = 10 # キリル文字

  def initialize
    @root = TrieNode.new('')
    @romaji_dictionary = {}
    # you need install natto https://github.com/buruzaemon/natto/
    @nm = Natto::MeCab.new
  end

  # Trie tree node
  class TrieNode
    attr_accessor :val, :score, :next, :is_word
    def initialize(val)
      @val = val
      @score = 0
      @next = {}
    end
  end

  def add_word(keyword, score)
    return if keyword.blank?
    return if score < 10
    keyword = normalize(keyword)
    return if keyword.to_s.empty?
    romaji = to_romaji(keyword)
    if @romaji_dictionary[romaji].nil? || @romaji_dictionary[romaji][1] < score
      @romaji_dictionary[romaji] = [keyword, score]
    end

    romaji += '+'
    current_node = @root
    for i in 0..romaji.size - 1
      char = romaji.slice(0, i + 1)
      idx = romaji[i].ord
      current_node.next[idx] = TrieNode.new(char) if current_node.next[idx].nil?
      current_node.next[idx].score += score
      current_node = current_node.next[idx]
    end
  end

  def suggest(keyword)
    return [] if keyword.blank? || keyword == '+'
    res = []
    keyword = normalize(keyword)
    romaji = to_romaji(keyword)

    current_node = @root
    # search keyword olog(keyword.length)
    for i in 0..romaji.size - 1
      idx = romaji[i].ord
      return res if current_node.next[idx].nil?
      current_node = current_node.next[idx]
    end
    # Traversal node
    next_level = current_node.next.sort_by { |r| r[1].score }.reverse
    until next_level.empty?
      node = next_level.shift
      if node[1].val.last == '+'
        next if @romaji_dictionary[node[1].val.chop].nil?
        sufrace = @romaji_dictionary[node[1].val.chop][0]
        res << [sufrace, node[1].score]
        return res if res.size > 9
      else
        next if node[1].next.empty?
        next_level << node[1].next.sort_by { |r| r[1].score }.reverse[0]
        next_level = next_level.sort_by { |r| r[1].score }.reverse
        next_level = next_level[0..9]
      end
    end
    res
  end

  def match(keyword)
    return '' if keyword.blank? || keyword == '+'
    keyword = normalize(keyword)
    romaji = to_romaji(keyword)

    current_node = @root
    for i in 0..romaji.size - 1
      idx = romaji[i].ord
      return '' if current_node.next[idx].nil?
      current_node = current_node.next[idx]
    end
    return '' if current_node.next['+'.ord].nil?
    @romaji_dictionary[current_node.val][0]
  end

  def spellcheck(keyword, max_cost = 3)
    return [] if keyword.blank? || keyword == '+'
    keyword += '+'
    current_node = @root

    current_row = []
    for i in 0..keyword.size
      current_row[i] = i
    end
    res = []
    # recursively search each branch of the trie
    current_node.next.map { |node| search_recursive(node[1], node[1].val[-1], keyword, current_row, res, max_cost) }
  end

  def levenshtein(word1, word2)
    columns = word1.size + 1
    rows = word2.size + 1
    current_row = [0]
    for column in 1..columns
      current_row << current_row[column - 1] + 1
    end

    for row in 1..rows
      previous_row = current_row
      current_row = [ previous_row[0] + 1 ]

      for column in 1..columns
        insert_cost = current_row[column - 1] + 1
        delete_cost = previous_row[column] + 1
        if word1[column - 1] != word2[row - 1]
          replace_cost = previous_row[ column - 1 ] + 1
        else
          replace_cost = previous_row[ column - 1 ]
        end
        current_row << [insert_cost, delete_cost, replace_cost].min
      end
    end
    return current_row[-1]
  end

  private

  def search_recursive(node, letter, keyword, previous_row, res, max_cost)
    current_row = [previous_row[0] + 1]

    for column in 1..keyword.size
      insert_cost = current_row[column - 1] + 1
      delete_cost = previous_row[column] + 1

      replace_cost = if keyword[column - 1] != letter
                       previous_row[column - 1] + 1
                     else
                       previous_row[column - 1]
                     end
      current_row << [insert_cost, delete_cost, replace_cost].min
    end

    if current_row[-1] != 0 && current_row[-1] <= max_cost &&
       letter == '+' && !@romaji_dictionary[node.val.chop].nil?
      res << [@romaji_dictionary[node.val.chop][0], node.score, current_row[-1]]
    end

    if current_row.min <= max_cost
      node.next.map { |next_node| search_recursive(next_node[1], next_node[1].val[-1], keyword, current_row, res, max_cost) }
    end
    res
  end

  def normalize(string)
    return '' if string.blank?
    # stringの長さはtrie treeの深さを決めるので、検索走査のスピードも影響を及ぼす、変更する場合は慎重に
    return '' if string.size > 30
    string.scrub!
    string.unicode_normalize!
    string = string.tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z').downcase
    string.gsub(/[^-’[^\p{P}]]|’$|’”$/, '')
  end

  def to_romaji(string)
    string = string.delete(' 　')
    string = to_yomi(string) if string =~ /\p{Han}/
    Romaji.kana2romaji(string)
  end

  def to_yomi(string)
    @nm.enum_parse(string).map do |node|
      if node.char_type.in?([KANJI, HIRAGANA, KATAKANA, KANJINUMERIC])
        node.feature.split(',')[8]
      else
        node.surface
      end
    end.join
  end
end