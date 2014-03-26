function Button (tint, frame, text, rect, callback, textTint)
  local button = {}
  button.tint = tint
  button.frame = frame
  button.text = text
  button.rect = rect
  button.callback = callback
  button.textTint = textTint

  return button
end

function drawButton(button, font)
  Renderer.addFrame(button.frame, button.rect.pos, button.rect.dim, button.tint)

  local size = Font.measure(font, button.text)
  local pos  = vec2(button.rect.pos.x + button.rect.dim.x / 2 - size.x / 2,
                    button.rect.pos.y + button.rect.dim.y / 2 - size.y / 2)
  Renderer.addText(font, button.text, pos, button.textTint)
end