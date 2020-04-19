#coding:utf-8

require 'json'
require 'gosu'
require 'securerandom'
#SecureRandom.uuid
require 'weakref'

class WeakHash < Hash
  def []=(key, value)
    super(key, WeakRef.new(value))
  end
end

module Cache
  module_function
  def image(name)
    @image_cache ||= {}
    @image_cache[name] ||= Gosu::Image.new("resources/#{name}.png", retro: true)
    @image_cache[name]
  end
end

class Reference
  attr_accessor :value
  def initialize(value = nil)
    @value = value
  end
  def inspect
    "<Reference to #{@value.inspect}>"
  end
  %i(to_s to_json).each do |x|
    define_method(x) do |*args, &block|
      @value.send(x, *args, &block)
    end
  end
end

# 用于将数据数组动态映射到控件对象的类。
class CachedMappedEnumerable
  include Enumerable
  attr_accessor :value, :mapping
  def initialize
    @cache = WeakHash.new
  end
  def each
    return to_enum(__callee__) unless block_given?
    tap do
      @value.each do |x|
        yield (@cache[x.object_id] ||= @mapping.call(x))
      end
    end
  end
end

module GUI
  module_function
  FONT = Gosu::Font.new(16, name: "SimHei", bold: false, italic: false, underline: true)
  def draw_sized(x, y, w, h, sx, sy, sw, sh)
    Cache.image("gui").subimage(sx, sy, sw, sh).draw(x, y, 0, w / sw.to_f, h / sh.to_f)
  end
  def draw_9patch(
    x, y, w, h,
    sx, sy, sw, sh,
    t, r, b, l,
    gt = 0, gr = 0, gb = 0, gl = 0
  )
    x -= gl
    y -= gt
    w += gl + gr
    h += gt + gb
    draw_sized(x, y, l, t, sx, sy, l, t)
    draw_sized(x + l, y, w - l - r, t, sx + l, sy, sw - l - r, t)
    draw_sized(x + w - r, y, r, t, sx + sw - r, sy, r, t)
    draw_sized(x, y + t, l, h - t - b, sx, sy + t, l, sh - t - b)
    draw_sized(x + l, y + t, w - l - r, h - t - b, sx + l, sy + t, sw - l - r, sh - t - b)
    draw_sized(x + w - r, y + t, r, h - t - b, sx + sw - r, sy + t, r, sh - t - b)
    draw_sized(x, y + h - b, l, b, sx, sy + sh - b, l, b)
    draw_sized(x + l, y + h - b, w - l - r, b, sx + l, sy + sh - b, sw - l - r, b)
    draw_sized(x + w - r, y + h - b, r, b, sx + sw - r, sy + sh - b, r, b)
  end
  def draw_decoration(
    x, y, w, h,
    tx, ty, tw, th,
    rx, ry, rw, rh,
    bx, by, bw, bh,
    lx, ly, lw, lh,
    gt = 0, gr = 0, gb = 0, gl = 0
  )
    x -= gl
    y -= gt
    w += gl + gr
    h += gt + gb
    draw_sized(x + (w - tw) / 2, y, tw, th, tx, ty, tw, th)
    draw_sized(x + w - rw, y + (h - rh) / 2, rw, rh, rx, ry, rw, rh)
    draw_sized(x + (w - bw) / 2, y + h - bh, bw, bh, bx, by, bw, bh)
    draw_sized(x, y + (h - lh) / 2, lw, lh, lx, ly, lw, lh)
  end
  def draw_bg(x, y, w, h)
    draw_sized(x, y, w, h, 8, 0, 1, 1)
  end
  def draw_dialog(x, y, w, h, options = {})
    if options[:focus]
      draw_9patch(x, y, w, h, 0, 34, 14, 14, 6, 7, 7, 6, 0, 6, 6, 0)
    else
      draw_9patch(x, y, w, h, 0, 20, 14, 14, 6, 7, 7, 6, 0, 6, 6, 0)
    end
  end
end

class Widget
  attr_accessor :x, :y, :width, :height
  # disabled应该被直接设置，disabled2应该被中间组件设置。
  attr_accessor :disabled, :disabled2
  %i().each do |x|
    define_method(x) do
      @style[x]
    end
    define_method(:"#{x}=") do |new_value|
      @style[x] = new_value
    end
  end
  def initialize
    @x = 0
    @y = 0
    @width = 32
    @height = 32
    @style = {}
    @disabled = false
    @disabled2 = false
  end
  def update
    should_click = @style[:active]
    @style[:enabled] = !disabled && !disabled2
    @style[:hover] = $window.cursor_x > @x && $window.cursor_x < @x + @width && $window.cursor_y > @y && $window.cursor_y < @y + @height
    @style[:active] = @style[:hover] && $window.button_down?(Gosu::MS_LEFT)
    @style[:active] ||= $window.button_down?(Gosu.const_get(@access_key)) if @access_key
    should_click &&= !@style[:active]
    should_click &&= @style[:enabled]
    click if should_click
  end
  def click
  end
  def draw
    Gosu.draw_rect(@x, @y, @width, @height, 0x10_ffffff, 0)
  end
  def intrinsic_size
    [0, 0]
  end
end

class Text < Widget
  attr_accessor :text
  def initialize
    super
    @text = ""
  end
  def update
    super
  end
  def draw
    super
    GUI::FONT.draw_text(@text, @x, @y + (@height - GUI::FONT.height) / 2, 0, 1, 1, 0xff_000000)
  end
end

class Button < Widget
  attr_accessor :text
  attr_accessor :access_key
  def initialize
    super
    @text = ""
    @access_key = ""
  end
  def update
    super
  end
  def click
    super
  end
  def draw
    super
    if !@style[:enabled]
    elsif @style[:active]
      GUI.draw_9patch(@x, @y, @width, @height, 4, 0, 4, 4, 2, 1, 1, 2, 0, 1, 1, 0)
    elsif @style[:hover]
      GUI.draw_9patch(@x, @y, @width, @height, 5, 1, 4, 4, 1, 2, 2, 1, 0, 1, 1, 0)
    else
      GUI.draw_9patch(@x, @y, @width, @height, 0, 0, 4, 4, 1, 2, 2, 1, 0, 1, 1, 0)
    end
    if @style[:modifier]
      GUI.draw_9patch(@x, @y, @width, @height, 0, 4, 4, 4, 1, 2, 2, 1, 0, 1, 1, 0)
      GUI.draw_9patch(@x, @y, @width, @height, 0, 8, 4, 4, 1, 2, 2, 1, 0, 1, 1, 0)
      GUI.draw_9patch(@x, @y, @width, @height, 0, 12, 4, 4, 1, 2, 2, 1, 0, 1, 1, 0)
      GUI.draw_9patch(@x, @y, @width, @height, 5, 6, 4, 4, 1, 2, 2, 1, 0, 1, 1, 0)
      GUI.draw_9patch(@x, @y, @width, @height, 5, 11, 4, 4, 1, 2, 2, 1, 0, 1, 1, 0)
      GUI.draw_9patch(@x, @y, @width, @height, 5, 16, 4, 4, 1, 2, 2, 1, 0, 1, 1, 0)
      GUI.draw_9patch(@x, @y, @width, @height, 4, 5, 4, 4, 2, 1, 1, 2, 0, 1, 1, 0)
      GUI.draw_9patch(@x, @y, @width, @height, 4, 10, 4, 4, 2, 1, 1, 2, 0, 1, 1, 0)
      GUI.draw_9patch(@x, @y, @width, @height, 4, 15, 4, 4, 2, 1, 1, 2, 0, 1, 1, 0)
    end
    GUI::FONT.draw_text(@text, @x + (@width - GUI::FONT.text_width(@text)) / 2, @y + (@height - GUI::FONT.height) / 2, 0, 1, 1, 0xff_000000)
  end
end

class TextField < Button
  LENGTH_LIMIT = 60
  SELECTION_COLOR = 0xcc_0000ff
  CARET_COLOR = 0xff_000000
  def initialize
    super
    @x = x
    @y = y
    @text_input = Gosu::TextInput.new
    @text_input.text = "***测试"
    @font = GUI::FONT
  end
  def update
    super
  end
  def draw
    super
    if false
      GUI.draw_9patch(@x, @y, @width, @height, 9, 9, 3, 3, 1, 1, 1, 1, 0, 0, 0, 0)
      pos_x = @x + @font.text_width(self.text[0...@text_input.caret_pos])
      sel_x = @x + @font.text_width(self.text[0...@text_input.selection_start])
      sel_w = pos_x - sel_x
      Gosu.draw_rect(sel_x, @y, sel_w, height, 0xcc_0000ff, 0)
      Gosu.draw_line(pos_x, @y, 0xff_000000, pos_x, @y + height, 0xff_000000, 0)
    elsif @style[:active]
      GUI.draw_9patch(@x, @y, @width, @height, 9, 6, 3, 3, 1, 1, 1, 1, 0, 0, 0, 0)
    elsif @style[:hover]
      GUI.draw_9patch(@x, @y, @width, @height, 9, 3, 3, 3, 1, 1, 1, 1, 0, 0, 0, 0)
    else
      GUI.draw_9patch(@x, @y, @width, @height, 9, 0, 3, 3, 1, 1, 1, 1, 0, 0, 0, 0)
    end
    @font.draw_text(text, @x + 4, @y + (@height - @font.height) / 2, 0, 1, 1, @style[:active] ? 0xff_ffffff : 0xff_000000)
  end
  def text
    @text_input.text
  end
  def text=(x)
    @text_input.text = x
  end
end

class Container < Widget
  # @children应为二维数组，如[[控件, 布局参数, ...], [控件, ...], ...]
  attr_accessor :children
  attr_accessor :ox, :oy
  def initialize
    super
    @ox = 0
    @oy = 0
    @children = []
  end
  def update
    super
    @children.each do |(child)|
      child.disabled2 = !@style[:enabled]
    end
    w, h = intrinsic_size
    @style[:scroll_up] = @oy > 0
    @style[:scroll_right] = w - @ox > @width
    @style[:scroll_down] = h - @oy > @height
    @style[:scroll_left] = @ox > 0
  end
  def draw
    super
    Gosu.clip_to(@x, @y, @width, @height) do
      @children.each do |(child)|
        if child.x < @x + @width && child.x + child.width >= @x &&
           child.y < @y + @height && child.y + child.height >= @y
          child.draw
        end
      end
    end
    GUI.draw_9patch(
      @x, @y, @width, @height,
      (@style[:scroll_up] ? 8 : 0) + (@style[:scroll_right] ? 8 : 0),
      49 + (@style[:scroll_down] ? 8 : 0) + (@style[:scroll_left] ? 8 : 0),
      8, 8,
      3, 3, 3, 3, 0, 0, 0, 0
    )
  end
  def clear
    @children.clear
  end
  def scroll_into_view(x, y)
    @ox -= @x - x if x < @x
    @ox += x - (@x + @width) if x >= @x + @width
    @oy -= @y - y if y < @y
    @oy += y - (@y + @height) if y >= @y + @height
  end
end

class AbsoluteContainer < Container
  def initialize
    super
  end
  def update
    super
    @children.each do |(child, x, y, width, height)|
      child.x = @x - @ox + x
      child.y = @y - @oy + y
      child.width = width
      child.height = height
      $window.mask_cursor(child) { child.update }
    end
  end
  def add(child, x, y, width, height)
    @children << [child, x, y, width, height]
  end
end

class GridContainer < Container
  Spring = Struct.new(:minimum, :stretch)
  attr_accessor :rows, :columns
  def initialize
    super
    @rows = []
    @columns = []
  end
  def update
    super
    rows_calculated = [0]
    rows_stretch_factor = @rows.reduce(0) { |sum, x| sum + x.stretch }
    raise "@rows have no stretchability" if rows_stretch_factor == 0
    rows_stretch_factor = (@height - @rows.reduce(0) { |sum, x| sum + x.minimum }) / rows_stretch_factor.to_f
    @rows.each_with_index do |spring, i|
      rows_calculated[i + 1] = rows_calculated[i] + spring.minimum + spring.stretch * rows_stretch_factor
    end
    columns_calculated = [0]
    columns_stretch_factor = @columns.reduce(0) { |sum, x| sum + x.stretch }
    raise "@columns have no stretchability" if columns_stretch_factor == 0
    columns_stretch_factor = (@width - @columns.reduce(0) { |sum, x| sum + x.minimum }) / columns_stretch_factor.to_f
    @columns.each_with_index do |spring, i|
      columns_calculated[i + 1] = columns_calculated[i] + spring.minimum + spring.stretch * columns_stretch_factor
    end
    @children.each do |(child, row, column, row_span, column_span)|
      raise "column out of range" if column >= @columns.length
      child.x = @x - @ox + columns_calculated[column]
      raise "row out of range" if row >= @rows.length
      child.y = @y - @oy + rows_calculated[row]
      child.width = columns_calculated[column + column_span] - columns_calculated[column]
      child.height = rows_calculated[row + row_span] - rows_calculated[row]
      $window.mask_cursor(child) { child.update }
    end
  end
  def add(child, row, column, row_span = 1, column_span = 1)
    @children << [child, row, column, row_span, column_span]
  end
end

class FlexContainer < Container
  def initialize
    super
    @direction = 1 # whatever
    @space = 10
  end
  def update
    super
    @children.each do |child|
      w, h = child[0].intrinsic_size
      child[0].width = child[1] * w + child[2]
      child[0].height = child[3] * h + child[4]
    end
    @children[0][0].x = @x - @ox
    @children[0][0].y = @y - @oy + (@height - @children[0][0].height) / 2
    y = @y - @oy
    @children.each do |(child)|
      child.x = @x - @ox
      child.y = y
      y += child.height + @space
    end
  end
  def intrinsic_size
    widths = []
    heights = []
    @children.each do |child|
      w, h = child[0].intrinsic_size
      widths << child[1] * w + child[2]
      heights << child[3] * h + child[4]
    end
    w = widths.shift
    w += widths.max
    w += @hspace
    h = heights.shift
    h = [h, heights.reduce(0, :+)].max
    h += @vspace * (@children.length - 2)
    [w, h]
  end
end

class TreeContainer < Container
  def initialize
    super
    @hspace = 30
    @vspace = 10
  end
  def update
    super
    @children.each do |child|
      w, h = child[0].intrinsic_size
      child[0].width = child[1] * w + child[2]
      child[0].height = child[3] * h + child[4]
    end
    @children[0][0].x = @x - @ox
    @children[0][0].y = @y - @oy + (@height - @children[0][0].height) / 2
    y = @y - @oy
    (1...@children.length).each do |i|
      @children[i][0].x = @x - @ox + @children[0][0].width + @hspace
      @children[i][0].y = y
      y += @children[i][0].height + @vspace
    end
    @children.each do |(child)|
      $window.mask_cursor(child) { child.update }
    end
  end
  def draw
    super
    (1...@children.length).each do |i|
      Gosu.draw_line(
        @children[0][0].x + @children[0][0].width / 2,
        @children[0][0].y + @children[0][0].height / 2,
        0xff_00ff00,
        @children[i][0].x,
        @children[i][0].y + @children[i][0].height / 2,
        0xff_00ffff,
        0
      )
    end
  end
  def intrinsic_size
    widths = []
    heights = []
    @children.each do |child|
      w, h = child[0].intrinsic_size
      widths << child[1] * w + child[2]
      heights << child[3] * h + child[4]
    end
    w = widths.shift
    w += widths.max
    w += @hspace
    h = heights.shift
    h = [h, heights.reduce(0, :+)].max
    h += @vspace * (@children.length - 2)
    [w, h]
  end
end

class UIParser
  def initialize
  end
  def construct(a)
    case a
    when Array
      a.map { |x| construct(x) }
    when Hash
      r = Object.const_get(a[:type]).new
      a.each do |key, value|
        next if key == :type
        r.send("#{key}=", construct(value))
      end
      r
    else
      a
    end
  end
end

class BooleanBoundButton < Button
  attr_accessor :data
  def update
    super
    @text = @data.value.to_s
  end
  def click
    super
    @data.value = !@data.value
  end
end

class SchemaParser
  ACCESS_KEYS = [
    "KB_Q",
    "KB_W",
    "KB_E",
    "KB_R",
    "KB_T",
  ]
  def initialize
    @access_key = -1
  end
  def construct(a)
    case a[:type]
    when "object"
      children = [
        [{type: "Text", text: a[:description]}, 0, 0, 1, 2],
      ]
      a[:properties].values.each_with_index do |p, i|
        children << [{type: "Text", text: p[:description].to_s}, i + 1, 0, 1, 1]
        children << [construct(p), i + 1, 1, 1, 1]
      end
      {
        type: "GridContainer",
        rows: Array.new(a[:properties].length + 1, {type: "GridContainer::Spring", minimum: 0, stretch: 1}),
        columns: [
          {type: "GridContainer::Spring", minimum: 32, stretch: 1},
          {type: "GridContainer::Spring", minimum: 32, stretch: 4},
        ],
        children: children,
      }
    when "string"
      {type: "TextField", access_key: new_access_key, text: ""}
    when "integer", "number"
      {type: "TextField", access_key: new_access_key, text: "0"}
    when "array"
      {type: "Button", access_key: new_access_key, text: "Edit"}
    when "boolean"
      {type: "BooleanBoundButton", access_key: new_access_key, data: {type: "Reference", value: false}}
    end
  end
  def new_access_key
    @access_key += 1
    ACCESS_KEYS[@access_key] || "KB_ISO"
  end
end

class Winode
  attr_accessor :children
  attr_accessor :title
  def initialize
    @children = []
    @title = "Unnamed"
  end
end

class MainWindow < Gosu::Window
  def initialize
    super 1280, 720
    self.caption = "ＳＬＺＵＮ"
    @button_down_count = {}

    @root = UIParser.new.construct(JSON.parse(File.read("uisample.json"), symbolize_names: true))
    #@root = UIParser.new.construct(SchemaParser.new.construct(JSON.parse(File.read("formatsample.json"), symbolize_names: true)))
  end
  def update
    @button_down_count.each do |id, value|
      if Gosu.button_down?(id)
        @button_down_count[id] += 1
      else
        @button_down_count[id] = 0
      end
    end
    @root.x = 0
    @root.y = 0
    @root.width = 640
    @root.height = 360
    mask_cursor(@root) do
      @root.update
    end
  end
  def draw
    Gosu.draw_rect(0, 0, width, height, 0xff_114514, 0)
    Gosu.transform(2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) do
      @root.draw
      if !needs_cursor? && $window.mouse_x >= 0 && $window.mouse_x < $window.width && $window.mouse_y >= 0 && $window.mouse_y < $window.height
        Gosu.flush
        GUI.draw_sized($window.cursor_x, $window.cursor_y, 17, 17, 14, 16, 17, 17)
      end
    end
  end
  def needs_cursor?
    false
  end
  def button_down(id)
    super
    @button_down_count[id] ||= 0
  end
  def button_down?(id)
    @button_down_count[id] && @button_down_count[id] != 0
  end
  def button_trigger?(id)
    @button_down_count[id] == 1
  end
  def button_repeat?(id)
    count = @button_down_count[id]
    count == 1 || (count % 6 == 1 && count > 13)
  end
  def cursor_x
    x = mouse_x / 2
    if @mask_cursor_region
      x = -2147483647 unless @mask_cursor_region.x <= x && x < @mask_cursor_region.x + @mask_cursor_region.width
    end
    x
  end
  def cursor_y
    y = mouse_y / 2
    if @mask_cursor_region
      y = -2147483647 unless @mask_cursor_region.y <= y && y < @mask_cursor_region.y + @mask_cursor_region.height
    end
    y
  end
  def mask_cursor(region)
    # 鼠标指针处在指定区域外时，假装鼠标指针在无穷远处来执行语句块
    # 区域是一个有x、y、width、height方法的对象
    previous_mask_cursor_region = @mask_cursor_region
    @mask_cursor_region = region
    yield
    @mask_cursor_region = previous_mask_cursor_region
  end
end

$window = MainWindow.new
$window.show
