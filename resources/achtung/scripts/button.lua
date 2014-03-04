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
  Renderer.addText(font, button.text, button.rect.pos, button.textTint)
end
