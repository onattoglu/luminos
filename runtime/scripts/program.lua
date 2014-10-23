dofile "scripts/core.lua"
dofile "scripts/table_ops.lua"
dofile "scripts/xform_ops.lua"
dofile "scripts/ui_controls.lua"
dofile "scripts/sdlkeys.lua"

concat_xform = clone_xform(concat_transform, {str_a = "Time: "})
concat_xform_2 = clone_xform(concat_transform, {str_a = "MouseX: " })

concat_xform.connections.str_b = {transform = time_xform, name = "time"}
concat_xform_2.connections.str_b = {transform = mouse_xform, name = "mx"}

create_node(300, 0, concat_xform)

-- clone_xform(concat_transform, { str_a = "Say", str_b = " Hey" })
-- can set name field later from the UI, but gets the concat_transform's name
--

top_transform = {
    name = "stdout",
    inputs = {
        input_str = {type = "string", default = ""},
    },
    connections = {
      input_str = { transform = concat_xform_2, name = "concat_str" }
    },
    outputs = {
        stdout = {type = "string"}
    },
    eval = function(self)
         self.outputs.stdout.value = self.inputs.input_str.value
    end
}

-- This table contains all the xforms present in the workspace
transforms = { concat_xform, concat_xform_2, top_transform, mouse_xform, time_xform}

counter = 0
function portProgramStart()
    for _k,transform in ipairs(transforms) do
        transform.visited = false
    end
    execTransform(top_transform)
    if (getKeyboardState(SDL.Key.LCTRL) == 3 and getKeyboardState(SDL.Key.A) == 1) then
        counter = counter+1
    end
        dbgText(6, tostring(counter))
    draw_nodes()
    return top_transform.outputs.stdout.value
end

