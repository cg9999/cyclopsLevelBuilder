# MIT License
#
# Copyright (c) 2023 Mark McKay
# https://github.com/blackears/cyclopsLevelBuilder
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

@tool
extends Node
class_name CyclopsBlock

signal mesh_changed

var control_mesh:ControlMesh
var selected:bool = false:
	get:
		return selected
	set(value):
		if value == selected:
			return
		selected = value
		mesh_changed.emit()

@export var block_data:BlockData:
	get:
		return block_data
	set(value):
		if block_data != value:
			block_data = value
#			control_mesh = ControlMesh.new()
			control_mesh = ControlMesh.new()
			control_mesh.init_block_data(block_data)
			
			mesh_changed.emit()

#			dirty = true

func intersect_ray_closest(origin:Vector3, dir:Vector3)->IntersectResults:
	if !block_data:
		return null
	
	var result:IntersectResults = control_mesh.intersect_ray_closest(origin, dir)
	if result:
		result.object = self
		
	return result

#func select():
##	for idx in control_mesh.get_face_indices():
##		control_mesh.faces[idx].selected = true
#	selected = true
#
#	mesh_changed.emit()
#
#func unselect():
#	for idx in control_mesh.get_face_indices():
#		control_mesh.faces[idx].selected = false
#
#	mesh_changed.emit()

func select_face(face_idx:int, select_type:Selection.Type = Selection.Type.REPLACE):
	if select_type == Selection.Type.REPLACE:
		for f in control_mesh.faces:
			f.selected = f.index == face_idx
	elif select_type == Selection.Type.ADD:
		control_mesh.faces[face_idx].selected = true
	elif select_type == Selection.Type.SUBTRACT:
		control_mesh.faces[face_idx].selected = true
	elif select_type == Selection.Type.TOGGLE:
		control_mesh.faces[face_idx].selected = !control_mesh.faces[face_idx].selected

	mesh_changed.emit()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

