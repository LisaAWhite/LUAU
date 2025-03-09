--- @class Label:Panel 
--- @field numeric boolean (default=false) If set to true, this label is configured to accept only numeric input.
--- @field editable boolean (default=false) If set to true, this label can be edited by clicking on it.
--- @field editableOnRightClick boolean (default=false) If set to true, this label can be edited by right-clicking on it.
--- @field editableOnDoubleClick boolean (default=false) If set to true, this label can be edited by double-clicking on it.
--- @field editing boolean (read-only) True if the user is currently editing this label.
--- @field text string The text displayed in this label.
--- @field markdown boolean (default=false) If true, this label is formatted using markdown.
--- @field characterLimit number The maximum number of characters this label can contain.
--- @field maxVisibleLines number The maximum number of lines this label can display.
--- @field maxVisibleCharacters number The maximum number of lines this label can display. Excess characters will still be stored, but won't be displayed. @see characterLimit to limit the length that text can be.
--- @field links boolean If true, links can be displayed within this panel.
--- @field linkHovered nil|string The id of the currently hovered link.
Label = {}

--- BeginEditing: Focus this label and begin editing it.
--- @return nil
function Label:BeginEditing()
	-- dummy implementation for documentation purposes only
end

--- @class LabelArgs:PanelArgs 
--- @field numeric nil|boolean (default=false) If set to true, this label is configured to accept only numeric input.
--- @field editable nil|boolean (default=false) If set to true, this label can be edited by clicking on it.
--- @field editableOnRightClick nil|boolean (default=false) If set to true, this label can be edited by right-clicking on it.
--- @field editableOnDoubleClick nil|boolean (default=false) If set to true, this label can be edited by double-clicking on it.
--- @field text nil|string The text displayed in this label.
--- @field markdown nil|boolean (default=false) If true, this label is formatted using markdown.
--- @field characterLimit nil|number The maximum number of characters this label can contain.
--- @field maxVisibleLines nil|number The maximum number of lines this label can display.
--- @field maxVisibleCharacters nil|number The maximum number of lines this label can display. Excess characters will still be stored, but won't be displayed. @see characterLimit to limit the length that text can be.
--- @field links nil|boolean If true, links can be displayed within this panel.
--- @field linkHovered nil|string The id of the currently hovered link.
LabelArgs = {}
