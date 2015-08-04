
local unescape_text

class HTMLNode
  outer_html: =>
    assert @buffer, "missing buffer"
    assert @pos, "missing pos"
    assert @end_pos, "missing end_pos"
    @buffer\sub @pos, @end_pos - 1

  inner_html: =>
    assert @buffer, "missing buffer"
    assert @inner_pos, "missing inner_pos"
    assert @end_inner_pos, "missing end_inner_pos"
    @buffer\sub @inner_pos, @end_inner_pos - 1

  inner_text: =>
    import extract_text from require "web_sanitize.html"
    text = extract_text @inner_html!
    unescape_text\match(text) or text

import R, S, V, P from require "lpeg"
import C, Cs, Ct, Cmt, Cg, Cb, Cc, Cp from require "lpeg"

unescape_char = P"&gt;" / ">" +
  P"&lt;" / "<" +
  P"&amp;" / "&" +
  P"&#x27;" / "'" +
  P"&#x2F;" / "/" +
  P"&quot;" / '"'

unescape_text = Cs (unescape_char + 1)^1

alphanum = R "az", "AZ", "09"
num = R "09"
hex = R "09", "af", "AF"

valid_char = P"&" * (alphanum^1 + P"#" * (num^1 + S"xX" * hex^1)) + P";"

white = S" \t\n"^0
word = (alphanum + S"._-")^1

value = C(word) +
  P'"' * C((1 - P'"')^0) * P'"' +
  P"'" * C((1 - P"'")^0) * P"'"

attribute = C(word) * (white * P"=" * white * value)^-1

scan_html = (html_text, callback) ->
  assert callback, "missing callback to scan_html"

  class BufferHTMLNode extends HTMLNode
    buffer: html_text

  tag_stack = {}

  fail_tag = ->
    error "tag failed!"

  check_tag = (str, _, pos, tag) ->
    node = {tag: tag\lower!, :pos}
    setmetatable node, BufferHTMLNode.__base
    table.insert tag_stack, node
    true

  check_close_tag = (str, end_pos, end_inner_pos, tag) ->
    top = tag_stack[#tag_stack]
    assert tag ==  top.tag, "tag close mismatch"

    top.end_inner_pos = end_inner_pos
    top.end_pos = end_pos
    callback tag_stack
    table.remove tag_stack
    true

  pop_tag = (str, pos, ...) ->
    table.remove tag_stack

  check_attribute = (str, pos, name, val) ->
    top = tag_stack[#tag_stack]
    top.attr or= {}
    top.attr[name\lower!] = unescape_text\match(val) or val
    true

  save_pos = (field) ->
    (str, pos) ->
      top = tag_stack[#tag_stack]
      top[field] = pos
      true

  open_tag = Cmt(Cp! * P"<" * white * C(word), check_tag) *
    (
      Cmt(white * attribute, check_attribute)^0 * white * Cmt("/" * white, pop_tag)^-1 * P">" * Cmt("", save_pos "inner_pos") +
      Cmt("", fail_tag)
    )

  close_tag = Cmt(Cp! * P"<" * white * P"/" * white * C(word) * white * P">", check_close_tag)
  html = (open_tag + close_tag + valid_char + P"<" + P(1 - P"<")^1)^0 * -1
  html\match html_text

{ :scan_html }